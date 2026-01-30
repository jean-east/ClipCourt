# ClipCourt — Technical Architecture

> "I'm learnding!" — but this architecture is production-grade.

## Overview

ClipCourt is a single-purpose iOS video editing app: watch a sports recording, toggle segments to keep, and export a trimmed video. The architecture prioritizes simplicity, responsiveness, and crash-resilient auto-save.

**Target:** iOS 17+ · Swift · SwiftUI · AVFoundation  
**Pattern:** MVVM (Model-View-ViewModel)  
**Dependencies:** Zero external — Apple frameworks only

---

## 1. App Structure (MVVM + SwiftUI)

```
┌─────────────────────────────────────────────────────┐
│                    SwiftUI Views                     │
│  ImportView · PlayerView · SegmentTimelineView ·     │
│  ExportView                                          │
├─────────────────────────────────────────────────────┤
│                   ViewModels                         │
│  PlayerViewModel · ExportViewModel                   │
├─────────────────────────────────────────────────────┤
│                    Services                          │
│  VideoPlayerService · SegmentManager ·               │
│  ExportService · PersistenceService                  │
├─────────────────────────────────────────────────────┤
│                     Models                           │
│  Project · Segment · ExportSettings                  │
└─────────────────────────────────────────────────────┘
```

### Layer Responsibilities

| Layer | Responsibility | Owns State? |
|-------|---------------|-------------|
| **Views** | Render UI, forward user intent to ViewModels | No (reads from VM `@Published`) |
| **ViewModels** | Orchestrate business logic, expose observable state | Yes (published properties) |
| **Services** | Encapsulate platform APIs (AVFoundation, Photos, FileManager) | No (stateless or internally managed) |
| **Models** | Plain data types — `Codable`, `Identifiable`, value semantics | N/A (pure data) |

---

## 2. Module Breakdown

### 2.1 VideoPlayer Module

**Owner:** `VideoPlayerService` → consumed by `PlayerViewModel`

- Wraps `AVPlayer` and `AVPlayerItem`
- Provides: play, pause, seek, set playback rate (0.25x–2x)
- Publishes current time via `CMTime` observation (`addPeriodicTimeObserver`)
- Hold-to-fast-forward: temporarily sets rate to 2x+ while gesture is active, reverts on release
- Fast-forward does **not** trigger segment state changes (per spec)
- Exposes `AVPlayerLayer` or `VideoPlayer` SwiftUI view for rendering

**Key Protocols:**
```swift
protocol VideoPlaybackControlling {
    var currentTime: CMTime { get }
    var duration: CMTime { get }
    var isPlaying: Bool { get }
    func play()
    func pause()
    func seek(to time: CMTime) async
    func setRate(_ rate: Float)
}
```

### 2.2 SegmentManager Module

**Owner:** `SegmentManager` service → consumed by `PlayerViewModel`

- Maintains an ordered array of `Segment` values
- Toggle on: creates a new segment starting at current playback time with `isIncluded = true`
- Toggle off: closes the current included segment (sets `endTime`)
- Supports retroactive editing: tap a segment in the timeline to toggle its `isIncluded`
- Merge logic: adjacent segments with the same `isIncluded` state are merged
- Thread-safe: all mutations go through `@MainActor` or a serial queue

**Key Protocols:**
```swift
protocol SegmentManaging {
    var segments: [Segment] { get }
    func beginIncluding(at time: CMTime)
    func stopIncluding(at time: CMTime)
    func toggleSegment(_ segment: Segment)
    func segment(at time: CMTime) -> Segment?
}
```

### 2.3 ExportEngine Module

**Owner:** `ExportService` → consumed by `ExportViewModel`

Two export paths, chosen by user:

#### Path A — Original Quality (Lossless)
- Uses `AVAssetExportSession` with `passthrough` preset
- Composes included segments into `AVMutableComposition`
- Fast (remux only, no re-encoding)
- Cuts land on nearest keyframe boundaries (spec-acceptable for sports content)

#### Path B — Faster/Lossy (Re-encoded)
- Uses `AVAssetReader` + `AVAssetWriter`
- Frame-accurate cuts (not keyframe-limited)
- Configurable output: resolution, bitrate, codec (H.264 default)
- Slower but produces smaller files

**Shared behavior:**
- Progress reported as `Double` (0.0–1.0) via async stream or `@Published`
- Output saved to temp directory, then moved to Photos library via `PHPhotoLibrary`
- Cancellable via `Task` cancellation

**Key Protocols:**
```swift
protocol VideoExporting {
    func exportLossless(asset: AVAsset, segments: [Segment], to url: URL) async throws -> URL
    func exportLossy(asset: AVAsset, segments: [Segment], settings: ExportSettings, to url: URL) async throws -> URL
    var progress: Double { get }
}
```

### 2.4 SessionPersistence Module

**Owner:** `PersistenceService`

- Serializes `Project` (which contains segments + metadata) to JSON in the app's Documents directory
- Auto-save triggers:
  1. Every segment state change (debounced 1 second)
  2. On `scenePhase` change to `.inactive` or `.background`
  3. On app termination notification (`willTerminateNotification`)
- On launch: checks for saved project → offers resume
- File format: `project_{id}.json` — simple, inspectable, no migration headaches for v1
- Video is **not** copied — only the `PHAsset` local identifier is stored

**Key Protocols:**
```swift
protocol ProjectPersisting {
    func save(_ project: Project) throws
    func load() throws -> Project?
    func delete() throws
}
```

---

## 3. Data Models

### 3.1 Project

```swift
struct Project: Codable, Identifiable {
    let id: UUID
    let assetIdentifier: String      // PHAsset.localIdentifier
    var segments: [Segment]
    var lastPlaybackTime: Double      // seconds, for resume
    var createdAt: Date
    var modifiedAt: Date
}
```

### 3.2 Segment

```swift
struct Segment: Codable, Identifiable {
    let id: UUID
    var startTime: Double             // seconds from video start
    var endTime: Double               // seconds from video start
    var isIncluded: Bool
}
```

### 3.3 ExportSettings

```swift
struct ExportSettings: Codable {
    enum ExportMode: String, Codable {
        case lossless       // AVAssetExportSession passthrough
        case lossy          // AVAssetReader + AVAssetWriter
    }
    var mode: ExportMode
    var outputQuality: Double         // 0.0–1.0, only for lossy
}
```

---

## 4. State Management Approach

### Observable Architecture (iOS 17+ `@Observable`)

- ViewModels use `@Observable` macro (new in iOS 17) for automatic SwiftUI invalidation
- No need for `ObservableObject` / `@Published` — cleaner, less boilerplate
- Views observe VMs via `@State` or `@Environment`

### State Flow

```
User Tap → View action → ViewModel method → Service call → Model mutation
                              ↓
                     @Observable publishes
                              ↓
                     SwiftUI re-renders
```

### Concurrency

- All UI-bound state is `@MainActor`
- Export runs on a background `Task`, reporting progress to the main actor
- `AVPlayer` time observation callback dispatches to main queue
- Auto-save debounce uses `Task` with `Task.sleep` cancellation pattern

---

## 5. File / Asset Handling Strategy

### No Copying

The app **never** copies the source video file into its own sandbox. Instead:

1. User picks a video via `PHPickerViewController` (wrapped in SwiftUI)
2. We obtain the `PHAsset.localIdentifier`
3. When playback is needed, we request an `AVAsset` via `PHImageManager.requestAVAsset`
4. The `AVAsset` URL points to the Photos library on disk — read-only, zero duplication

### Why This Works

- Sports recordings are large (500MB–2GB). Copying doubles storage.
- `PHAsset` references survive app restarts (the identifier is stable)
- If the user deletes the source video from Photos, we detect this on resume and show an appropriate error

### Export Output

- Export writes to `FileManager.default.temporaryDirectory`
- On completion, saved to Photos via `PHPhotoLibrary.shared().performChanges`
- Temp file cleaned up after save confirmation

---

## 6. Auto-Save Strategy

### Triggers

| Event | Action |
|-------|--------|
| Segment created/modified | Debounced save (1s delay) |
| Toggle state change | Debounced save (1s delay) |
| Scene goes `.inactive` | Immediate save |
| Scene goes `.background` | Immediate save |
| `willTerminateNotification` | Immediate save (best-effort) |

### Debounce Implementation

```swift
// In PlayerViewModel
private var saveTask: Task<Void, Never>?

func scheduleSave() {
    saveTask?.cancel()
    saveTask = Task { @MainActor in
        try? await Task.sleep(for: .seconds(1))
        guard !Task.isCancelled else { return }
        try? persistenceService.save(project)
    }
}
```

### Resume Flow

```
App Launch
    → PersistenceService.load()
    → Project exists?
        YES → Verify PHAsset still exists
            → Valid: Restore PlayerView with segments + playback position
            → Invalid: Show "Source video deleted" error, clear project
        NO → Show ImportView
```

---

## 7. Export Pipeline

### Composition Building (Shared)

Both export paths start by building an `AVMutableComposition`:

```
1. Filter segments where isIncluded == true
2. Sort by startTime
3. For each included segment:
   - Insert time range into AVMutableComposition video + audio tracks
   - Accumulate total duration
4. Result: single composition with only "kept" portions, in order
```

### Path A: Lossless Export

```
AVMutableComposition
    → AVAssetExportSession(asset: composition, presetName: .passthrough)
    → outputURL = temp directory
    → outputFileType = .mp4
    → exportAsynchronously
    → Monitor progress via timer polling session.progress
    → On completion: save to Photos
```

**Trade-offs:** Fast, no quality loss. Cuts may land on nearest keyframe (±0.5s for typical sports video). Acceptable for the use case.

### Path B: Lossy/Re-encoded Export

```
AVMutableComposition
    → AVAssetReader(asset: composition)
        → Add video output (decompressed frames)
        → Add audio output (PCM samples)
    → AVAssetWriter(outputURL: temp, fileType: .mp4)
        → Add video input (H.264, configurable bitrate)
        → Add audio input (AAC)
    → Read sample buffers in loop:
        while reader.status == .reading {
            if let buffer = videoOutput.copyNextSampleBuffer() {
                videoInput.append(buffer)
            }
            // same for audio
        }
    → Track progress via bytes written / estimated total
    → On completion: save to Photos
```

**Trade-offs:** Slower, smaller files, frame-accurate cuts. Good for sharing.

### Error Handling

- Export is wrapped in Swift concurrency `Task` — cancellable
- Errors surface to `ExportViewModel.exportError` → displayed in `ExportView`
- Temp files cleaned up in `defer` block regardless of outcome

---

## 8. Directory Structure

```
ClipCourt/
├── ClipCourtApp.swift
├── Models/
│   ├── Project.swift
│   ├── Segment.swift
│   └── ExportSettings.swift
├── ViewModels/
│   ├── PlayerViewModel.swift
│   └── ExportViewModel.swift
├── Views/
│   ├── PlayerView.swift
│   ├── SegmentTimelineView.swift
│   ├── ExportView.swift
│   └── ImportView.swift
├── Services/
│   ├── VideoPlayerService.swift
│   ├── SegmentManager.swift
│   ├── ExportService.swift
│   └── PersistenceService.swift
├── Utilities/
│   ├── TimeFormatter.swift
│   └── Constants.swift
├── Assets.xcassets/
│   ├── AccentColor.colorset/
│   │   └── Contents.json
│   ├── AppIcon.appiconset/
│   │   └── Contents.json
│   └── Contents.json
└── Info.plist
```

---

## 9. Future Considerations

- **SwiftData migration:** v1 uses JSON persistence for simplicity. If multi-project support is added, migrate to SwiftData for relational queries.
- **Mac Catalyst:** The SwiftUI views are resolution-independent. `VideoPlayerService` uses `AVPlayer` which works on macOS. Minimal adaptation needed.
- **FFmpegKit:** If export flexibility needs grow (custom codecs, filters), FFmpegKit can replace the `AVAssetReader+Writer` path.

---

*Architecture authored by Ralph "I bent my Wookiee" Wiggum, Senior iOS Architect* 🏗️
