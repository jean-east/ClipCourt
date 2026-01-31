# ClipCourt — LumaFusion-Style Timeline Redesign

## Design Specification

> **Author:** Ralph (Senior UI/UX Designer)
> **Date:** 2025-07-16
> **Status:** Ready for Engineering
> **Scope:** Replace the current scrub-bar-based navigation with a professional, LumaFusion-style scrolling timeline with fixed playhead.

---

## Table of Contents

1. [Overview & Rationale](#1-overview--rationale)
2. [What Gets Removed](#2-what-gets-removed)
3. [Layout Architecture](#3-layout-architecture)
4. [Visual Design](#4-visual-design)
5. [Interactions & Gestures](#5-interactions--gestures)
6. [Zoom System](#6-zoom-system)
7. [Time Ruler](#7-time-ruler)
8. [Playback & Auto-Scroll](#8-playback--auto-scroll)
9. [Segment Interactions](#9-segment-interactions)
10. [Animations & Motion](#10-animations--motion)
11. [Export Button Padding Fix](#11-export-button-padding-fix)
12. [Landscape Adaptation](#12-landscape-adaptation)
13. [Accessibility](#13-accessibility)
14. [Implementation Notes](#14-implementation-notes)
15. [Appendix: Dimension Summary](#15-appendix-dimension-summary)

---

## 1. Overview & Rationale

The current timeline design has two separate navigation elements:

1. A **stock SwiftUI `Slider`** (the "scrub bar") — provides scrubbing but uses a system circular thumb that doesn't match our design language. Filed as BUG-007.
2. A **`SegmentTimelineView`** — shows included/excluded segments with pinch-to-zoom support, but the playhead moves along the content rather than staying anchored.

This redesign **unifies both into a single LumaFusion-style scrolling timeline** where the playhead is fixed at the horizontal center of the screen and the timeline content scrolls underneath it. This is the standard for professional video editing apps (LumaFusion, DaVinci Resolve, Final Cut) and is immediately intuitive to users.

### What Changes

| Before | After |
|--------|-------|
| Stock `Slider` for scrubbing | **Removed entirely** |
| Playhead moves across timeline content | **Playhead fixed at horizontal center** |
| Timeline scrolls during zoom only | **Timeline always scrolls; content moves under playhead** |
| No time ruler | **Time ruler with adaptive tick marks at bottom** |
| Tap anywhere on timeline = seek | **Drag to scrub; tap segment = future select** |
| Timeline + scrub bar = two separate rows | **Single unified timeline component** |

---

## 2. What Gets Removed

### Scrub Bar — DELETE

Remove the `scrubBar` computed property from `PlayerView.swift` entirely. This is the stock `Slider`:

```
// REMOVE this from PlayerView:
private var scrubBar: some View { ... }
```

Remove all references to `scrubBar` in both `portraitLayout` and `landscapeRightPanel`.

### Portrait Layout Spacing Change

The vertical stack currently flows:

```
Video → Status Row → Scrub Bar → Segment Timeline → Controls → Toggle → Export
```

New flow:

```
Video → Status Row → Timeline (unified, taller) → Controls → Toggle → Export
```

The ~48pt freed up from removing the scrub bar gets redistributed into the new timeline height.

---

## 3. Layout Architecture

### Core Concept: Fixed Playhead, Scrolling Content

```
┌─────────────────────────────────────────────┐
│                    ▼  ← playhead (fixed)     │
│ ▓▓▓▓▓░░░░░▓▓▓▓▓▓▓▓▓░░░░░░░▓▓▓▓▓░░░░░░░░  │ ← segments scroll L/R
│ ···|····|····|····|····|····|····|····|····  │ ← time ruler (scrolls with content)
└─────────────────────────────────────────────┘
```

The playhead is a **stationary vertical line** at the exact horizontal center of the timeline container. All timeline content (segments + time ruler) scroll underneath it. The current playback time always corresponds to whatever is under the playhead.

### Structural Hierarchy

```
ZStack {
    // Layer 1: Scrollable content (segments + time ruler)
    // Offset by -scrollOffset, width = containerWidth * zoomScale
    VStack(spacing: 0) {
        segmentTrack    // height: fills available space minus ruler
        timeRuler       // height: 18pt, pinned at bottom of content
    }
    
    // Layer 2: Fixed playhead overlay (does NOT scroll)
    // Positioned at horizontal center of container
    PlayheadView()
}
.clipShape(RoundedRectangle(cornerRadius: 10))
```

### Timeline Frame — Portrait

| Property | Value | Notes |
|----------|-------|-------|
| **Total height** | 72pt | Was 48pt; expanded because scrub bar is gone. Segments get more vertical space and the time ruler fits at the bottom. |
| **Segment track height** | 54pt | `72pt - 18pt (ruler)` |
| **Time ruler height** | 18pt | Compact row of tick marks + labels |
| **Horizontal padding** | 16pt each side | Matches existing `Design.md` spacing |
| **Top spacing** | 4pt below status row | Same as current scrub bar top padding |
| **Corner radius** | 10pt | Uniform on all four corners — see §4.2 for corner bug fix |

### Content Width

```
contentWidth = containerWidth × zoomScale
```

At `zoomScale = 1.0`, the entire video fills exactly the container width (minus conceptual left/right padding for the playhead at start/end — see §3.1).

### 3.1 Edge Padding (Playhead at Start/End of Video)

When the playhead is at `t = 0`, the start of the timeline should align with the center of the container (under the playhead). Similarly, at `t = duration`, the end of the timeline should be at center. This means the scrollable content needs **virtual padding** of `containerWidth / 2` on each side.

```
|<-- padding -->|<-------- content (segments) -------->|<-- padding -->|
                                    ▼ playhead at center

scrollOffset range: 0 ... contentWidth
  where offset 0 = playhead at t=0
  where offset contentWidth = playhead at t=duration
```

The virtual padding areas show `ccSurface` (empty timeline background). No segments render there.

---

## 4. Visual Design

### 4.1 Playhead

The playhead is the most prominent element — it's the user's "you are here" indicator.

```
        ▽        ← downward triangle (indicator cap)
        │
        │        ← thin vertical line, full segment track height
        │
```

| Property | Value |
|----------|-------|
| **Line width** | 2pt |
| **Line color** | `Color.white` (pure white for maximum contrast against both ccSurface and ccInclude segments) |
| **Line height** | Full segment track height (54pt portrait, 36pt landscape) — does NOT extend into time ruler |
| **Triangle cap** | Downward-pointing equilateral triangle, 10pt wide × 7pt tall |
| **Triangle color** | Same as line: `Color.white` |
| **Triangle position** | Centered above the line, at the very top of the timeline container (above segment track) |
| **Horizontal position** | Exactly `containerWidth / 2` — the dead center of the visible timeline |
| **Z-order** | Topmost layer — renders above segments, above time ruler |
| **Shadow** | 1pt black shadow at 30% opacity, offset (0, 1) — subtle depth to separate from bright segments |

> **Design note:** Use `Color.white` rather than `ccTextPrimary` (#F2F2F7 Snow) for the playhead. Pure white pops more against Rally Green segments. The existing `Triangle` shape in `SegmentTimelineView.swift` can be reused — just needs re-orientation (currently inverted/downward, which is correct for this design since the triangle points down from the top).

### 4.2 Timeline Background & Corner Radius

| Property | Value |
|----------|-------|
| **Background fill** | `ccSurface` (#1A1A24 Charcoal) |
| **Corner radius** | 10pt, **uniform on all four corners** |
| **Clip shape** | `RoundedRectangle(cornerRadius: 10)` applied to the outermost container |

**Corner bug fix:** The current `SegmentTimelineView` applies `RoundedRectangle(cornerRadius: 8)` to the background fill but clips the overall ZStack separately. Segments can bleed past the rounded corners because the clip is on the ZStack and the background is a separate layer. **Fix:** Apply a single `.clipShape(RoundedRectangle(cornerRadius: 10))` to the outermost container ZStack. This clips everything uniformly — segments, ruler, background — and guarantees no corner bleed.

### 4.3 Segments

Segments fill the **segment track** area (above the time ruler).

| Segment State | Fill | Notes |
|---------------|------|-------|
| **Included (kept)** | `ccInclude` (#30D158 Rally Green) at 100% opacity | Solid filled rectangle. Height fills the full segment track (54pt portrait). |
| **Excluded / Gap** | Transparent (shows `ccSurface` background) | No fill. The charcoal background shows through. |
| **Active included (under playhead)** | `ccInclude` at 100% | Same as other included segments. **No** brightness boost or color shift (fixes the BUG-010 two-greens issue). |
| **Active excluded (under playhead)** | `ccTextTertiary` (#48484A Ash) at 20% opacity | Faint highlight so user can see which gap they're in. |

| Property | Value |
|----------|-------|
| **Height** | Full segment track height (54pt portrait, 36pt landscape) |
| **Corner radius** | 0pt (segments are flush rectangles — the outer container clip rounds the edges) |
| **Minimum width** | 2pt (segments narrower than 2pt at current zoom are rendered at 2pt minimum) |
| **Border separators** | 0.5pt vertical line in `ccSurface` at segment boundaries, visible when `zoomScale > 2.0` |

### 4.4 Current Time Label

**Keep the existing status row position and style.** The status row above the timeline already shows:

```
◉ KEEPING                    00:12:34 / 00:35:20
```

No changes to this element. The timestamp continues to update in real-time as the timeline scrolls / plays.

### 4.5 Zoom Level Badge

Reuse the existing zoom badge design from `SegmentTimelineView`:

| Property | Value |
|----------|-------|
| **Text** | `String(format: "%.1fx", zoomScale)` |
| **Font** | `.caption2.bold()` |
| **Color** | `ccTextSecondary` |
| **Background** | `ccSurfaceElevated` in `Capsule()` |
| **Position** | Centered above the timeline, offset y: -22pt |
| **Visibility** | Shows during pinch gesture, fades out 1s after gesture ends |

---

## 5. Interactions & Gestures

### 5.1 Horizontal Drag → Scrub

**This replaces the old `Slider` for seeking.**

| Property | Value |
|----------|-------|
| **Gesture** | `DragGesture(minimumDistance: 1)` on the timeline container |
| **Behavior** | Dragging left moves the timeline content to the left (reveals later content; advances playback time). Dragging right does the opposite. The playhead stays fixed; the content moves. |
| **Mapping** | `dragDelta (pts) → timeDelta = dragDelta / contentWidth × totalDuration` |
| **Seek call** | On `.onChanged`, compute new time from scroll offset and call `viewModel.seek(to:)` |
| **Always active** | Drag works at **all** zoom levels, including 1.0x. This is the primary scrubbing mechanism now. |
| **Sensitivity** | 1:1 point-to-content mapping. A drag of 100pt scrolls the content by 100pt worth of time. |
| **Bounds** | Clamp scroll offset to `[0, contentWidth]` — can't scroll past start or end of video. |

**Interaction with playback:** If the user drags while playing and `scrubWhileKeeping == "pauseOnScrub"` and `isIncluding`, pause playback (same behavior as the old slider's `onEditingChanged`).

### 5.2 Pinch → Zoom

| Property | Value |
|----------|-------|
| **Gesture** | `MagnificationGesture()` on the timeline container |
| **Anchor point** | Playhead center (since the playhead is fixed at center, zooming always anchors at the current playback time) |
| **Behavior** | Pinch out = zoom in (more detail, fewer seconds visible). Pinch in = zoom out. |
| **Range** | `minZoom ... maxZoom` (see §6) |
| **Snap-to-overview** | If zoom drops below 1.15x on gesture end, snap to 1.0x with spring animation |

**Anchor math:** Because the playhead is always at center, zooming is simple — the current time stays at center. Only the `contentWidth` changes; `scrollOffset` is recomputed so the time under the playhead doesn't shift.

```swift
let currentTime = scrollOffsetToTime(scrollOffset) // time at playhead
zoomScale = newZoom
scrollOffset = timeToScrollOffset(currentTime) // recalculate offset for new zoom
```

### 5.3 Tap on Segment

| Gesture | Behavior |
|---------|----------|
| **Single tap** | **No action** in v1. Reserved for future: select segment for info panel. |

> We no longer seek on tap. Dragging is the scrub mechanism. Tap-to-seek on a scrolling timeline is disorienting because the content would jump under the fixed playhead, which feels like a glitch.

### 5.4 Long-Press on Segment

| Property | Value |
|----------|-------|
| **Duration** | 0.5 seconds |
| **Behavior** | **Delete the segment.** The long-pressed segment is removed: its time range becomes excluded (or if it was excluded, it becomes included). This is a **toggle of the individual segment**, same as the current `viewModel.toggleSegment(segment)`. |
| **Haptic** | `.impactOccurred(.medium)` on trigger |
| **Visual feedback** | Segment flashes briefly (opacity 0.5 → 1.0 over 0.2s) to confirm the action |
| **Confirmation** | None required — action is undoable by long-pressing again |

> **Simplification from current:** The old design had long-press toggling between include/exclude. New design: long-press on an **included** segment = **delete** (set to excluded). Long-press on an excluded segment = **no action** (or future: restore). This is one-directional for safety. Users create segments via the KEEP toggle; they delete segments via long-press on the timeline.

### 5.5 Gesture Priority

```
1. Pinch (MagnificationGesture) — highest priority when two fingers detected
2. Long-press (0.5s) — triggers on sustained single-finger hold
3. Drag (DragGesture) — default single-finger movement
```

Use `.simultaneousGesture` for pinch (so it can coexist with drag detection) and `.gesture` for the drag. Long-press uses `.onLongPressGesture(minimumDuration: 0.5)` on individual segment views.

---

## 6. Zoom System

### Zoom Range

| Level | Value | What's Visible (40-min video, iPhone 15 @ 361pt container) |
|-------|-------|----|
| **Minimum (overview)** | `1.0x` | Entire video fits in container width |
| **Maximum** | `maxZoom = totalDuration / 5.0` (capped at 100x) | ~5 seconds fills the screen width |

The max zoom is **dynamic** based on video duration:
- 30-second video → max zoom ≈ 6x (5s visible)
- 5-minute video → max zoom ≈ 60x (5s visible)
- 40-minute video → max zoom = 100x (cap; ~24s visible, which is fine)

```swift
let maxZoom = min(totalDuration / 5.0, 100.0)
```

### Zoom Anchor

Zoom always anchors at the **playhead position** (center of container). The time under the playhead before and after zoom is identical. This feels natural because the playhead is the user's focus point.

### Snap-to-Overview

| Property | Value |
|----------|-------|
| **Threshold** | 1.15x |
| **Behavior** | If zoom is below 1.15x when the pinch gesture ends, animate to 1.0x |
| **Animation** | `.spring(response: 0.3, dampingFraction: 0.8)` |

---

## 7. Time Ruler

The time ruler is a thin strip at the **bottom** of the timeline container, inside the clip region. It scrolls with the segment content.

```
│ 0:00   0:30   1:00   1:30   2:00   2:30   3:00 │
│  |      |      |      |      |      |      |    │
```

### Dimensions

| Property | Value |
|----------|-------|
| **Height** | 18pt total (12pt for tick marks + labels, 6pt top padding) |
| **Position** | Bottom of the timeline container, below the segment track |
| **Background** | Transparent (shows `ccSurface` underneath) |
| **Separator** | 0.5pt horizontal line in `ccTextTertiary` at 30% opacity along the top edge of the ruler, separating it from the segment track |

### Tick Marks

| Property | Value |
|----------|-------|
| **Major ticks** | 1pt wide, 8pt tall, `ccTextTertiary` (#48484A) at 60% opacity |
| **Minor ticks** | 0.5pt wide, 4pt tall, `ccTextTertiary` at 30% opacity |
| **Labels** | Below major ticks only |

### Adaptive Tick Density

The ruler adapts its tick spacing based on the current zoom level, so labels never overlap and the density feels appropriate.

| Zoom Level (approx seconds visible on screen) | Major Tick Interval | Minor Tick Interval | Label Format |
|-----------------------------------------------|--------------------|--------------------|-------------|
| > 30 minutes visible | 5 minutes | 1 minute | `0:00`, `5:00`, `10:00` |
| 10–30 minutes visible | 2 minutes | 30 seconds | `0:00`, `2:00`, `4:00` |
| 3–10 minutes visible | 1 minute | 15 seconds | `0:00`, `1:00`, `2:00` |
| 1–3 minutes visible | 30 seconds | 10 seconds | `0:30`, `1:00`, `1:30` |
| 20–60 seconds visible | 10 seconds | 5 seconds | `0:10`, `0:20`, `0:30` |
| 5–20 seconds visible | 5 seconds | 1 second | `0:05`, `0:10`, `0:15` |
| < 5 seconds visible | 1 second | 0.5 seconds | `0:01`, `0:02`, `0:03` |

### Label Style

| Property | Value |
|----------|-------|
| **Font** | `.system(size: 9, weight: .medium, design: .monospaced)` |
| **Color** | `ccTextTertiary` (#48484A) at 80% opacity |
| **Position** | Centered below their major tick mark |
| **Format** | `M:SS` for times under 1 hour, `H:MM:SS` for times ≥ 1 hour |

### Viewport Culling

Only render ticks and labels that are within the visible scroll window (plus 10% padding on each side to avoid pop-in). Same culling strategy as the existing segment rendering.

---

## 8. Playback & Auto-Scroll

### During Playback

When `viewModel.isPlaying == true`, the timeline auto-scrolls so the current playback time stays under the fixed playhead.

```swift
// On each time observer tick (~30fps):
scrollOffset = timeToScrollOffset(viewModel.currentTime)
```

This is simpler than the current auto-follow logic because the playhead is always at center — there's no "40% leading edge" offset to calculate. The formula is:

```swift
func timeToScrollOffset(_ time: Double) -> CGFloat {
    (time / totalDuration) * contentWidth
}
```

| Property | Value |
|----------|-------|
| **Scroll animation during playback** | `.linear(duration: 1/30)` — matches the time observer interval for buttery smooth motion |
| **User override** | If user begins dragging during playback, auto-scroll pauses immediately |
| **Resume auto-scroll** | 2 seconds after user's last touch ends (same as current `autoFollowResumeDelay`) |

### When Paused

The timeline holds its position. The user can drag to scrub freely. The displayed time updates in real-time as they drag.

### Seek Behavior

When the user drags, call `viewModel.seek(to:)` on every `.onChanged` event. The video player will show the frame at that time. This provides visual feedback during scrubbing.

> **Performance note:** The existing time observer interval is `1/30` seconds. During drag-scrubbing, seek calls may fire more frequently than frame updates — this is fine; AVPlayer handles redundant seeks gracefully.

---

## 9. Segment Interactions

### Visual Feedback During Active Recording

When `viewModel.isIncluding == true` (the KEEP toggle is active), the timeline should show the **progressive green fill** in real-time. This already works in the current `SegmentTimelineView` via the `keepingStartTime` logic. Preserve this behavior exactly.

The visual logic:
- Segments between `keepingStartTime` and `currentTime` render as `ccInclude`
- The segment containing `currentTime` is capped at `currentTime` (progressive fill)
- Segments ahead of the playhead retain their committed state

### Long-Press Delete

When a user long-presses an included segment:

1. **Haptic:** `.impactOccurred(.medium)`
2. **Visual:** Segment briefly flashes (opacity dip to 0.5 then back to 1.0, 0.2s)
3. **Action:** `viewModel.toggleSegment(segment)` — sets `isIncluded = false`
4. **Result:** Segment visually disappears (becomes transparent, showing ccSurface background)

When a user long-presses an **excluded** area: **no action.** (The gap is not a discrete segment from the user's perspective — it's the absence of a kept clip.)

### Scroll Mini-Map

When zoomed in (`zoomScale > 1.0`), show a mini-map indicator at the very bottom of the timeline (overlaying the time ruler). This is already implemented — keep the existing `scrollIndicator` from `SegmentTimelineView`:

| Property | Value |
|----------|-------|
| **Height** | 2pt |
| **Color** | `ccTextSecondary` at 40% opacity |
| **Width** | Proportional to visible fraction: `containerWidth / contentWidth × containerWidth` |
| **Position** | Bottom of container, offset by scroll position fraction |
| **Min width** | 20pt (so it's always visible/tappable) |

---

## 10. Animations & Motion

### Momentum Scrolling

After the user lifts their finger from a drag, the timeline should continue scrolling with **momentum**, then decelerate to a stop. This mimics the feel of `UIScrollView` momentum.

| Property | Value |
|----------|-------|
| **Deceleration rate** | `0.998` per frame (similar to UIScrollView's `.normal` deceleration) |
| **Minimum velocity to trigger momentum** | 50 pt/s |
| **Implementation** | Track velocity from the last few drag samples. On gesture end, apply a `withAnimation(.interpolatingSpring(stiffness: 50, damping: 15))` to the final resting offset. Or use a `TimelineView(.animation)` to manually animate the offset with exponential decay. |
| **Boundary behavior** | When momentum would scroll past bounds (before `t=0` or after `t=duration`), apply a **rubber-band effect**: overshoot by up to 20pt, then spring back to the boundary. |

> **Implementation suggestion:** SwiftUI doesn't have built-in scroll physics for custom views. Options: (A) Use a `ScrollViewReader` wrapper if feasible, (B) Track velocity manually from `DragGesture.Value.velocity` (available iOS 17+) and apply deceleration via `withAnimation`, or (C) Use a `CADisplayLink`-driven animation for full control.

### Playback Scroll

| Property | Value |
|----------|-------|
| **Smoothness** | Must feel perfectly smooth at 60fps. Use `.linear(duration: 1/30)` animation on each time observer tick to interpolate the offset. |
| **No jitter** | Avoid discrete jumps. Each tick should smoothly interpolate from the previous offset. |

### Pinch Zoom

| Property | Value |
|----------|-------|
| **During pinch** | Immediate response (no animation — directly track gesture magnitude) |
| **Snap-to-overview** | `.spring(response: 0.3, dampingFraction: 0.8)` when snapping back to 1.0x |
| **Zoom badge** | Fade in 0.15s, fade out 0.2s |

### Segment Appearance/Disappearance

| Event | Animation |
|-------|-----------|
| **New segment created (recording)** | Progressive fill grows in real-time (no spring, just continuous update) |
| **Segment deleted (long-press)** | Opacity fade out 0.25s, then remove |
| **Zoom scale change** | Content width changes immediately track the gesture; no separate animation needed |

---

## 11. Export Button Padding Fix

The current `exportPill` in `PlayerView.swift`:

```swift
Label("Export", systemImage: "square.and.arrow.up")
    .font(.headline.weight(.semibold))
    .foregroundStyle(Color.ccTextPrimary)
    .padding(.horizontal, 20)
    .frame(height: 44)
    .background(Color.ccExport, in: Capsule())
```

**Problem:** The `Label` layout positions the icon and text based on their natural baselines, but the 44pt frame doesn't account for the icon's visual weight. The result looks slightly top-heavy — the content doesn't appear vertically centered within the capsule.

**Fix — exact padding values:**

```swift
Label("Export", systemImage: "square.and.arrow.up")
    .font(.headline.weight(.semibold))
    .foregroundStyle(Color.ccTextPrimary)
    .padding(.horizontal, 20)
    .padding(.vertical, 12)            // ← explicit vertical padding instead of fixed frame height
    .background(Color.ccExport, in: Capsule())
```

| Property | Old Value | New Value |
|----------|-----------|-----------|
| **Vertical sizing** | `.frame(height: 44)` | `.padding(.vertical, 12)` |
| **Horizontal padding** | `.padding(.horizontal, 20)` | `.padding(.horizontal, 20)` (unchanged) |
| **Result** | Icon+text forced into 44pt frame, can look off-center | Icon+text centered by their intrinsic size + 12pt above and below. Natural height ≈ 44-46pt. |

The `.padding(.vertical, 12)` approach lets the `Label`'s intrinsic content drive centering, with equal space above and below. This properly centers both the SF Symbol icon and text together.

Apply the same fix to the landscape `landscapeExportButton` if it uses the same `exportPill`.

---

## 12. Landscape Adaptation

### Timeline in Landscape

In the current landscape layout, the timeline lives inside the right panel at 36pt height. With the redesign:

| Property | Portrait | Landscape |
|----------|----------|-----------|
| **Timeline total height** | 72pt | 48pt |
| **Segment track height** | 54pt | 34pt |
| **Time ruler height** | 18pt | 14pt |
| **Corner radius** | 10pt | 8pt |
| **Ruler label font size** | 9pt | 8pt |

The scrub bar is removed from landscape too. The timeline in the right panel becomes the sole navigation/scrubbing element.

### Right Panel Layout Update

```
┌───────────────┐
│ ◉ KEEPING     │  ← Status indicator + timestamp
│ 14:52 / 35:20 │
├───────────────┤
│               │
│  [Timeline]   │  ← Unified scrolling timeline (was: scrub bar + timeline)
│  [Ruler     ] │
│               │
├───────────────┤
│  [⏪] [▶] [⏩] │  ← Playback controls
│    [1x ▾]     │
├───────────────┤
│ ╔═══════════╗ │
│ ║  ● TOGGLE ║ │
│ ╚═══════════╝ │
├───────────────┤
│   [Export ↗]  │
└───────────────┘
```

---

## 13. Accessibility

### VoiceOver

| Element | Label | Hint | Traits |
|---------|-------|------|--------|
| **Timeline (whole)** | "Playback timeline, current time [X:XX] of [X:XX]" | "Swipe left or right to scrub. Pinch to zoom." | `.isAdjustable` |
| **Segment (included)** | "Kept clip, [start] to [end], [duration]" | "Double-tap and hold to remove" | `.isButton` |
| **Playhead** | Decorative — not independently focusable | — | — |
| **Time ruler** | Decorative — not independently focusable | — | — |

### Adjustable Trait

When VoiceOver focuses on the timeline:
- **Swipe up** = seek forward 10 seconds
- **Swipe down** = seek backward 10 seconds
- Announce new time after each adjustment

### Reduce Motion

When `UIAccessibility.isReduceMotionEnabled`:
- No momentum scrolling — drag stops immediately on finger lift
- No rubber-band bounce at boundaries
- Zoom snap-to-overview: instant (no spring)
- Segment delete: instant disappearance (no fade)

---

## 14. Implementation Notes

### Files to Modify

| File | Changes |
|------|---------|
| `Views/SegmentTimelineView.swift` | **Major rewrite.** Implement fixed-playhead scrolling model, time ruler, new gesture system, momentum scrolling. |
| `Views/PlayerView.swift` | Remove `scrubBar` property and all references. Update timeline `.frame(height:)` to new values. Fix export button padding. Remove scrub bar from landscape panel. |
| `Utilities/Constants.swift` | Update `Constants.UI.timelineHeight` to 72. Add `timelineHeightLandscape = 48`. Add `timelineRulerHeight = 18`. |

### Files NOT to Modify

| File | Reason |
|------|--------|
| `Models/Segment.swift` | Data model unchanged |
| `ViewModels/PlayerViewModel.swift` | ViewModel API unchanged — still uses `seek(to:)`, `currentTime`, `duration`, `segments` |
| `Utilities/Color+ClipCourt.swift` | No new colors needed |

### Key State Variables (in new SegmentTimelineView)

```swift
@State private var zoomScale: CGFloat = 1.0       // 1.0 = overview
@State private var scrollOffset: CGFloat = 0       // points; maps to time
@State private var gestureStartZoom: CGFloat = 1.0
@State private var dragVelocity: CGFloat = 0       // for momentum
@State private var isUserDragging: Bool = false
@State private var isMomentumScrolling: Bool = false
```

### Scroll ↔ Time Conversion

```swift
// Time → scroll offset
func timeToOffset(_ time: Double, contentWidth: CGFloat, duration: Double) -> CGFloat {
    (time / duration) * contentWidth
}

// Scroll offset → time
func offsetToTime(_ offset: CGFloat, contentWidth: CGFloat, duration: Double) -> Double {
    (Double(offset) / Double(contentWidth)) * duration
}
```

### Existing Code to Preserve

- **Viewport culling** — the current `visibleSegments` filter in `timelineContent` is efficient and should be preserved.
- **Progressive fill during recording** — the `keepingStartTime` / `visuallyIncluded` / `visualEndTime` logic is correct and should be kept.
- **Triangle shape** — `Triangle` struct can be reused for the playhead cap.
- **Zoom badge** — existing badge UI is fine; just update positioning.

---

## 15. Appendix: Dimension Summary

### Portrait (iPhone)

| Element | Width | Height | Margin/Padding |
|---------|-------|--------|----------------|
| **Timeline container** | Screen width - 32pt | 72pt | H: 16pt, top: 4pt |
| **Segment track** | Container width × zoomScale | 54pt | — |
| **Time ruler** | Container width × zoomScale | 18pt | — |
| **Playhead line** | 2pt | 54pt (segment track only) | Centered horizontally |
| **Playhead triangle** | 10pt wide × 7pt tall | — | Above line, centered |
| **Ruler major tick** | 1pt | 8pt | — |
| **Ruler minor tick** | 0.5pt | 4pt | — |
| **Ruler label** | Auto | 9pt font | Centered below tick |

### Landscape (iPhone)

| Element | Width | Height |
|---------|-------|--------|
| **Timeline container** | Panel width - 16pt | 48pt |
| **Segment track** | Container width × zoomScale | 34pt |
| **Time ruler** | Container width × zoomScale | 14pt |
| **Playhead line** | 2pt | 34pt |

### Shared Constants

| Constant | Value |
|----------|-------|
| `timelineHeight` (portrait) | 72pt |
| `timelineHeightLandscape` | 48pt |
| `timelineRulerHeight` (portrait) | 18pt |
| `timelineRulerHeightLandscape` | 14pt |
| `timelineCornerRadius` (portrait) | 10pt |
| `timelineCornerRadiusLandscape` | 8pt |
| `playheadWidth` | 2pt |
| `playheadTriangleWidth` | 10pt |
| `playheadTriangleHeight` | 7pt |
| `minZoom` | 1.0 |
| `maxZoom` | `min(duration / 5.0, 100.0)` |
| `snapThreshold` | 1.15 |
| `autoFollowResumeDelay` | 2 seconds |
| `momentumDeceleration` | 0.998 per frame |
| `edgePadding` | `containerWidth / 2` (virtual) |

---

## Design Revision History

| Date | Version | Notes |
|------|---------|-------|
| 2025-07-16 | 1.0 | Initial timeline redesign spec — Designer Ralph 🎨 |

---

> The old scrub bar had a good run. But this timeline? This timeline goes to eleven. 🎚️
