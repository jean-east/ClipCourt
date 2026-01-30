# ClipCourt — Product Specification

> A video tool that lets you watch a long sports recording once, mark which parts to keep, and export a trimmed video.

## Design Philosophy

**Simple. Lovable. Complete.**

- **Simple** — One screen, one workflow. No menus to dig through, no modes to learn. You watch, you toggle, you export. A first-time user should figure it out in 30 seconds without a tutorial.
- **Lovable** — Feels good to use. Responsive, fluid, satisfying feedback. The kind of app you tell your teammates about. Small delightful touches over feature bloat.
- **Complete** — Ships with everything you need and nothing you don't. No half-baked features. Every interaction polished. v1 should feel like a finished product, not a beta.

## Problem

Sports players record full games (20–40 minutes) but only care about the live gameplay. Current video editors require timeline scrubbing and manual in/out point placement — tedious for a simple cut job.

## Solution

Playback *is* the editing process. You watch the video, toggle a "keep" switch during the parts that matter, and export. One pass, one output.

## Core Functions

### 1. Import
- Pick a video from the device camera roll
- Support landscape and portrait
- One project at a time

### 2. Playback
- Standard video playback with adjustable speed: **0.25x / 0.5x / 1x / 1.5x / 2x**
- Scrub to seek forward/backward
- Hold-to-fast-forward at selectable speed (**2x default**, higher options available)
  - Video plays visually during FF (not a blind skip)
  - FF does **not** auto-toggle the include/exclude state

### 3. Include/Exclude Toggle
- **Off (exclude) by default** — nothing is included until you toggle on
- Toggle via tap or swipe
- Clear visual indicator of current state (e.g. colored border, recording-style cue)
- Marks the currently playing section as kept or cut in real time

### 4. Segment Timeline
- Mini-timeline showing included (full color) vs excluded (dimmed) regions
- **Pinch-to-zoom** — horizontally expandable and shrinkable
  - Default zoom: full video fits the screen width (overview)
  - Pinch out to zoom in for precision navigation on long videos
  - Pinch in to zoom back out to overview
  - When zoomed in, the timeline scrolls horizontally and auto-follows the playhead during playback
  - Playhead stays centered when possible while zoomed in
- Tappable — jump to any segment to review or re-adjust toggle regions
- Designed for one-pass use but supports going back

### 5. Export
- One continuous video with only included segments
- Two modes:
  - **Original quality** (no re-encoding, just cutting)
  - **Faster/lossy** (re-encoded, smaller file, quicker processing)
- Original audio preserved
- Saved directly to device (no cloud)
- Progress bar during export

### 6. Auto-Save
- Session progress auto-saved on interruption (app close, crash, etc.)
- Resumable on next open

## Out of Scope (Noted for Future)
- Frame-by-frame stepping
- Drawing/annotation on frames
- Audio controls / muting
- Multiple simultaneous projects

## Platforms

### v1: iOS (native)
- **Priority:** Ship a great iOS app first
- macOS follows via Mac Catalyst or SwiftUI multiplatform (near-free from the iOS codebase)
- Windows and Android deferred — may require separate codebases or a cross-platform rewrite

### Priority Order (long-term)
1. iOS
2. macOS
3. Windows
4. Android

## Tech Stack (iOS / v1)

### Language & UI
- **Swift** + **SwiftUI**
- Minimum target: **iOS 17+**
- Standard Xcode project — no external package manager dependencies for v1

### Video Playback
- **AVFoundation / AVPlayer** — native Apple video engine
- Handles scrubbing, variable playback speed, and frame-accurate seeking

### Video Export
- **AVAssetExportSession** — lossless cuts (fast, remuxes at keyframe boundaries, no re-encoding)
- **AVAssetReader + AVAssetWriter** — re-encoded/lossy option (precise cuts, smaller output, slower)
- Potential future addition: **FFmpegKit** if more export flexibility is needed

### Storage & Auto-Save
- Session state (toggle regions, playback position) persisted via **SwiftData** or local **JSON** in the app's documents directory
- Video referenced via **PHAsset** — no copying the full file into the app

### macOS Path
- **Mac Catalyst** or **SwiftUI multiplatform** — leverages the iOS codebase with minimal adaptation
