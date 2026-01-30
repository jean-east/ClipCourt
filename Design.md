# ClipCourt — UI/UX Design Document

> "My cat's breath smells like cat food." — Ralph Wiggum
>
> This app's breath smells like **butter**. One screen. One workflow. Zero confusion.

---

## Table of Contents

1. [Design Principles](#design-principles)
2. [Color Palette](#color-palette)
3. [Typography](#typography)
4. [Layout — Portrait](#layout--portrait)
5. [Layout — Landscape](#layout--landscape)
6. [The Toggle](#the-toggle)
7. [Segment Timeline](#segment-timeline)
8. [Playback Controls](#playback-controls)
9. [Export Flow](#export-flow)
10. [Empty State](#empty-state)
11. [Auto-Save & Resume](#auto-save--resume)
12. [Micro-interactions & Delight](#micro-interactions--delight)
13. [Accessibility](#accessibility)
14. [SF Symbols Reference](#sf-symbols-reference)
15. [Appendix: Dimension Summary](#appendix-dimension-summary)

---

## Design Principles

I'm a design principal! And these are my principles:

1. **Glanceable** — The toggle state (recording or not) must be obvious from across a gym. No squinting.
2. **One-handed** — All primary controls reachable with the thumb in portrait. Landscape uses bottom-edge controls.
3. **Non-destructive** — Every action is reversible. The user can't break anything.
4. **Progressive disclosure** — Show only what's needed. Speed selector, export options — they appear when called upon.
5. **Dark-first** — Athletes film in gyms, courts, fields. Dark UI reduces glare and eye strain. Light mode supported but dark is default and primary.

---

## Color Palette

I picked these colors with my eyes! They're the best colors because they go together like chocolate and more chocolate.

### Core Palette (Dark Mode — Primary)

| Role | Name | Hex | Usage |
|------|------|-----|-------|
| **Background** | Midnight | `#0A0A0F` | Primary app background |
| **Surface** | Charcoal | `#1A1A24` | Cards, controls background, timeline tray |
| **Surface Elevated** | Slate | `#252533` | Pressed states, secondary panels |
| **Text Primary** | Snow | `#F2F2F7` | Primary labels, timestamps |
| **Text Secondary** | Mist | `#8E8E93` | Secondary labels, dimmed info |
| **Text Tertiary** | Ash | `#48484A` | Disabled text, placeholders |
| **Accent / Include** | Rally Green | `#30D158` | "Included" state — segments, toggle, border glow |
| **Accent Bright** | Rally Glow | `#34E060` | Pulse glow peak, active indicators |
| **Exclude / Dimmed** | Graphite | `#3A3A3C` | Excluded segments on timeline |
| **Danger / Alert** | Court Red | `#FF453A` | Destructive actions (discard), errors |
| **Export / Progress** | Signal Blue | `#0A84FF` | Export button, progress indicators |
| **Speed Indicator** | Fast Orange | `#FF9F0A` | Fast-forward overlay, speed badge |

### Core Palette (Light Mode — Secondary)

| Role | Name | Hex |
|------|------|-----|
| **Background** | Paper | `#FFFFFF` |
| **Surface** | Cloud | `#F2F2F7` |
| **Surface Elevated** | Fog | `#E5E5EA` |
| **Text Primary** | Ink | `#1C1C1E` |
| **Text Secondary** | Stone | `#8E8E93` |
| **Accent / Include** | Rally Green | `#28CD41` |
| **Exclude / Dimmed** | Light Graphite | `#D1D1D6` |
| **Danger** | Court Red | `#FF3B30` |
| **Export** | Signal Blue | `#007AFF` |

### Semantic Mapping

```swift
// In Assets.xcassets or via Color extension:
extension Color {
    static let ccBackground    = Color("Background")    // adaptive
    static let ccSurface       = Color("Surface")
    static let ccSurfaceElevated = Color("SurfaceElevated")
    static let ccTextPrimary   = Color("TextPrimary")
    static let ccTextSecondary = Color("TextSecondary")
    static let ccInclude       = Color("Include")       // Rally Green
    static let ccExclude       = Color("Exclude")       // Graphite
    static let ccDanger        = Color("Danger")
    static let ccExport        = Color("Export")
    static let ccSpeed         = Color("Speed")
}
```

---

## Typography

My typography teacher says I'm the best at letters!

### Font Stack
- **Primary:** SF Pro (system default — no custom fonts needed)
- **Monospace (timestamps):** SF Mono
- **All text uses Dynamic Type** — specify styles, not fixed sizes

| Element | Style | Weight | Size (Default) | Tracking |
|---------|-------|--------|-----------------|----------|
| Toggle label ("RECORDING" / "PAUSED") | `.caption` | Bold | 12pt | 1.5pt (wide) |
| Timestamp (current / total) | SF Mono `.caption` | Medium | 12pt | 0 |
| Speed badge ("2x") | `.caption2` | Bold | 11pt | 0.5pt |
| Export button label | `.headline` | Semibold | 17pt | 0 |
| Export sheet title | `.title2` | Bold | 22pt | 0 |
| Export sheet body | `.body` | Regular | 17pt | 0 |
| Empty state headline | `.title2` | Bold | 22pt | 0 |
| Empty state body | `.body` | Regular | 17pt | 0 |

---

## Layout — Portrait

This is the up-and-downy one! Like how I stand up.

### Structure (top to bottom)

```
┌──────────────────────────────────┐
│         Status Bar (system)      │  ← system, transparent bg
├──────────────────────────────────┤
│                                  │
│                                  │
│          VIDEO PLAYER            │  ← 16:9 aspect ratio maintained
│        (letterboxed if           │     fills width, vertically centered
│         aspect differs)          │     in its container
│                                  │
│                                  │
├──────────────────────────────────┤
│  ◉ RECORDING          00:12:34  │  ← Status bar: toggle state + timestamp
├──────────────────────────────────┤
│  ▶ advancement scrub bar        │  ← Playback scrub bar (full width)
├──────────────────────────────────┤
│  [segment timeline]             │  ← Mini-timeline: colored segments
│  ▓▓▓▓▓░░░░▓▓▓░░░░░▓▓▓▓▓▓▓░░░  │     48pt tall, tappable
├──────────────────────────────────┤
│  [⏪]  [ ▶ ]  [⏩]    [1x ▾]   │  ← Playback controls row
├──────────────────────────────────┤
│                                  │
│     ╔══════════════════════╗     │
│     ║   ● TOGGLE BUTTON   ║     │  ← THE BIG TOGGLE: 72pt tall
│     ╚══════════════════════╝     │     full width minus 32pt margins
│                                  │
├──────────────────────────────────┤
│         [Export ↗]               │  ← Export button (bottom right)
├──────────────────────────────────┤
│       Home Indicator (system)    │
└──────────────────────────────────┘
```

### Dimensions — Portrait (iPhone)

| Element | Frame | Notes |
|---------|-------|-------|
| **Video Player** | Width: 100% · Aspect: match source (usually 16:9) | Letterboxed with `#0A0A0F` bars |
| **Status Row** | Height: 36pt · Padding: H 16pt | Left: toggle indicator + label; Right: elapsed / total |
| **Scrub Bar** | Height: 44pt (tap target) · Visual track: 4pt tall, expands to 8pt on drag | Full width, 16pt horizontal padding |
| **Segment Timeline** | Height: 48pt · Padding: H 16pt, V 4pt | Rounded rect segments, 4pt corner radius |
| **Controls Row** | Height: 52pt · Padding: H 16pt | Centered playback buttons, speed selector right-aligned |
| **Toggle Button** | Height: 72pt · Margin: H 16pt · Corner radius: 20pt | Full-width minus margins |
| **Export Button** | Height: 44pt · Width: 120pt · Corner radius: 22pt | Bottom-right, 16pt from edge and safe area |
| **Safe Area Padding** | Bottom: respect home indicator | Top: below status bar |

### Spacing Between Sections
- Video player → Status Row: **0pt** (status row overlays bottom of player area)
- Status Row → Scrub Bar: **4pt**
- Scrub Bar → Segment Timeline: **8pt**
- Segment Timeline → Controls Row: **8pt**
- Controls Row → Toggle Button: **12pt**
- Toggle Button → Export area: **12pt**

---

## Layout — Landscape

The sideways one! I like when the phone goes on its tummy.

### Structure (landscape)

```
┌────────────────────────────────────────────────────────────────────┐
│                                                │                   │
│                                                │  ◉ RECORDING      │
│                                                │                   │
│              VIDEO PLAYER                      │  [ ▶ ]  [1x ▾]   │
│           (fills left 70%)                     │                   │
│                                                │  ╔══════════════╗ │
│                                                │  ║ ● TOGGLE BTN ║ │
│                                                │  ╚══════════════╝ │
│                                                │                   │
│                                                │  [Export ↗]       │
├────────────────────────────────────────────────┴───────────────────┤
│  ◀ scrub bar ─────────────────────●───────────────────────── ▶     │
│  [▓▓▓▓▓░░░░▓▓▓░░░░░▓▓▓▓▓▓▓░░░] 00:12:34 / 00:35:20              │
└────────────────────────────────────────────────────────────────────┘
```

### Dimensions — Landscape

| Element | Frame | Notes |
|---------|-------|-------|
| **Video Player** | Width: ~70% of screen · Height: fills available above bottom strip | Aspect-fit, centered |
| **Right Panel** | Width: ~30% · Padding: 16pt all sides | Toggle state, controls, toggle button, export |
| **Bottom Strip** | Height: 80pt total | Contains scrub bar (top 44pt) + segment timeline (bottom 36pt) |
| **Toggle Button (landscape)** | Height: 56pt · Full panel width minus 16pt padding | Slightly shorter in landscape |

### Adaptive Behavior
- Transition between portrait/landscape is **animated** (0.35s ease-in-out)
- Video player maintains aspect ratio; never crops
- Toggle button remains prominent in both orientations — always the largest interactive element
- On **iPad**: Same landscape layout is used in all orientations (side panel always visible); video player area is larger

---

## The Toggle

This is the big red — well, GREEN — button! Miss Hoover says I'm not allowed to push buttons, but this one's different.

### Anatomy

The toggle is a **single large, full-width button** that lives below the playback controls. It is THE primary interaction element.

```
OFF state (Exclude — default):
┌─────────────────────────────────────────┐
│                                         │
│          ○  TAP TO RECORD               │
│                                         │
└─────────────────────────────────────────┘
Background: ccSurface (#1A1A24)
Border: 2pt solid ccExclude (#3A3A3C)
Label: ccTextSecondary (#8E8E93)
Icon: circle (SF Symbol: "circle") — 20pt

ON state (Include — recording):
╔═════════════════════════════════════════╗
║                                         ║
║          ● RECORDING                    ║
║                                         ║
╚═════════════════════════════════════════╝
Background: Rally Green at 15% opacity (#30D158, alpha 0.15)
Border: 2.5pt solid Rally Green (#30D158)
Label: Rally Green (#30D158), Bold
Icon: "record.circle" (SF Symbol) — 20pt, Rally Green, with pulse animation
```

### Toggle Behavior

| Property | Detail |
|----------|--------|
| **Tap** | Toggles between include/exclude |
| **Visual transition** | 0.2s spring animation (response: 0.5, dampingFraction: 0.7) |
| **Haptic — ON** | `.impactOccurred(.medium)` + 50ms delay + `.impactOccurred(.light)` (double-tap feel) |
| **Haptic — OFF** | `.impactOccurred(.light)` (single soft tap — asymmetric, ON feels weightier) |
| **Sound** | None (gyms are noisy, sounds would be lost; haptics are the feedback) |
| **Border glow (ON)** | 8pt soft outer shadow in Rally Green at 40% opacity, pulsing between 30%-50% opacity over 2s (infinite, easeInOut) |
| **Record indicator** | SF Symbol `record.circle` pulses scale 1.0→1.15→1.0 in sync with border glow |

### Video Player Border Glow

When the toggle is ON, the **video player itself** gets a subtle 3pt inner border glow in Rally Green (`#30D158`) at 25% opacity. This provides a persistent ambient indicator visible even if the user isn't looking at the toggle.

- **ON**: 3pt inner border, Rally Green at 25% opacity, 0.3s fade-in
- **OFF**: Border fades to transparent over 0.2s

### Why This Design

The toggle is a **fat, obvious, impossible-to-miss button** because:
1. Athletes may be glancing at the phone while physically active (watching game film during a break)
2. The included/excluded state must be unambiguous at arm's length
3. Tap targets must be generous — sweaty fingers, one-handed use

---

## Segment Timeline

I drawed a timeline once and Miss Hoover put it on the fridge! This one goes on the phone.

### Visual Design

The segment timeline is a **horizontal bar** that represents the full video duration. Segments are colored blocks within this bar.

```
Full timeline bar:
┌──────────────────────────────────────────────────────┐
│▓▓▓▓▓▓▓░░░░░░░▓▓▓░░░░░░░░░░░▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░│
└──────────────────────────────────────────────────────┘
 ▓ = Included (Rally Green #30D158, full opacity)
 ░ = Excluded (Graphite #3A3A3C, or surface color)
```

### Dimensions

| Property | Value |
|----------|-------|
| **Height** | 48pt (portrait), 36pt (landscape) |
| **Corner radius (bar)** | 8pt |
| **Corner radius (segments)** | 0pt (segments are flush within the bar — the bar itself is rounded) |
| **Horizontal padding** | 16pt from screen edge |
| **Background** | ccSurface (`#1A1A24`) — visible for excluded regions |
| **Included segment color** | Rally Green (`#30D158`) at 100% opacity |
| **Excluded segment color** | Transparent (shows bar background) |
| **Minimum segment width** | 2pt — segments shorter than 2pt at current scale are rendered at 2pt to remain visible |
| **Playhead** | 2pt wide vertical line, Snow (`#F2F2F7`), full height of timeline, with 8pt tall inverted triangle cap on top |

### Playhead Cap

```
    ▼       ← 8pt wide triangle, Snow colored
    │       ← 2pt line, full height
────┼────
```

### Interaction

| Gesture | Behavior |
|---------|----------|
| **Tap** | Jump playback to tapped position; playhead animates to new position (0.15s ease-out) |
| **Drag** | Scrub through video; playhead follows finger; video frames update in real-time (throttled to 10fps during drag for performance) |
| **Long press (0.5s)** | Future: could enable segment split/adjust — **v1: no action** |

### Density for Long Videos

For a 40-minute video on an iPhone 15 (portrait width 361pt usable):
- Total usable width: ~329pt (361 - 32pt padding)
- 1 second ≈ 0.137pt
- 10-second segment ≈ 1.37pt → below minimum, rendered at 2pt
- 60-second segment ≈ 8.2pt → comfortably visible and tappable

This works. Short segments cluster together visually but remain distinguishable. The timeline serves as a **map**, not a precision tool — the scrub bar handles precise seeking.

### Active Segment Highlight

The segment currently being played (the one under the playhead) gets a subtle **brightness boost** — included segments go to Rally Glow (`#34E060`), excluded segments show a faint outline (1pt, `#48484A`).

---

## Playback Controls

I can play AND pause! That's like stopping and going at the same time.

### Control Row Layout (Portrait)

```
┌─────────────────────────────────────────────┐
│  [⏪15]     [ ▶▐▐ ]     [15⏩]     [1x ▾]  │
└─────────────────────────────────────────────┘
     ↑           ↑           ↑          ↑
  Skip Back   Play/Pause  Skip Fwd   Speed
```

### Button Specifications

| Button | SF Symbol | Size | Tap Target | Color |
|--------|-----------|------|------------|-------|
| **Skip Back 15s** | `gobackward.15` | 24pt | 44×44pt | ccTextSecondary (`#8E8E93`) |
| **Play** | `play.fill` | 32pt | 52×52pt | ccTextPrimary (`#F2F2F7`) |
| **Pause** | `pause.fill` | 32pt | 52×52pt | ccTextPrimary (`#F2F2F7`) |
| **Skip Forward 15s** | `goforward.15` | 24pt | 44×44pt | ccTextSecondary (`#8E8E93`) |
| **Speed Selector** | `gauge.with.needle.fill` | 18pt (icon) + label | 60×44pt | ccTextSecondary, text label shows current speed |

### Play/Pause Transition
- SF Symbol morphing animation: `play.fill` ↔ `pause.fill` with `.symbolEffect(.replace.downUp)`
- Duration: 0.2s
- Haptic: `.selectionChanged()` (very subtle)

### Scrub Bar

```
00:12:34 ────────────●──────────────── 00:35:20
          ← elapsed   ↑ thumb   remaining →
```

| Property | Value |
|----------|-------|
| **Track height (idle)** | 4pt |
| **Track height (dragging)** | 8pt — expands with 0.15s ease-out |
| **Track color (elapsed)** | ccTextPrimary (`#F2F2F7`) at 80% |
| **Track color (remaining)** | ccTextSecondary (`#8E8E93`) at 40% |
| **Thumb** | 16pt circle (idle), 24pt circle (dragging); Snow (`#F2F2F7`) with subtle drop shadow |
| **Timestamps** | SF Mono `.caption` Medium, ccTextSecondary; left-aligned (elapsed) and right-aligned (total) |
| **Tap target height** | 44pt (generous, even though track is thin) |
| **Frame preview (on drag)** | Thumbnail popover above thumb, 120×68pt (16:9), rounded 8pt corners, with timestamp label below. Appears after 0.1s of dragging. |

### Speed Selector

Tapping the speed button opens an **inline pill picker** that slides up from the button position:

```
          ┌─────────────────────┐
          │ 0.25x  0.5x  1x    │
          │ 1.5x   2x          │
          ╰─────────────────────╯
                 [1x ▾]         ← button
```

| Property | Value |
|----------|-------|
| **Background** | ccSurfaceElevated (`#252533`) |
| **Corner radius** | 12pt |
| **Pill padding** | 8pt H, 6pt V per option |
| **Selected state** | Rally Green text + underline (2pt, Rally Green) |
| **Unselected state** | ccTextSecondary |
| **Dismiss** | Tap outside, or tap the speed button again |
| **Animation** | `.spring(response: 0.3, dampingFraction: 0.8)` scale + opacity |
| **Haptic** | `.selectionChanged()` on each option tap |

### Hold-to-Fast-Forward

This is the secret trick! Like finding a dollar in your pocket.

**Mechanism:** Press and hold the **Skip Forward** button (`goforward.15`).

| Phase | Time | Behavior |
|-------|------|----------|
| **Tap** | < 0.3s | Skip forward 15 seconds (standard) |
| **Hold start** | 0.3s | Trigger fast-forward mode |
| **FF active** | 0.3s+ | Playback accelerates to the selected FF speed (default 2x). Video continues playing visually. |
| **Release** | — | Returns to previous playback speed |

**Visual feedback during FF:**

```
┌──────────────────────────────────────┐
│              ▶▶ 2x                   │  ← overlay in center of video
│         Fast Orange (#FF9F0A)        │     SF Symbol: "forward.fill"
│         Fade in 0.15s, opacity 70%   │     + speed label
└──────────────────────────────────────┘
```

- The `goforward.15` button **morphs** to `forward.fill` while held, tinted Fast Orange
- Haptic: `.impactOccurred(.rigid)` on FF engage; `.impactOccurred(.soft)` on release
- The scrub bar thumb and timeline playhead both animate smoothly during FF
- **Toggle state is NOT affected** during FF (per spec)

**Discoverability:** On first use (detected via UserDefaults flag), a **tooltip** appears near the skip-forward button after the user's first tap:

```
┌──────────────────────────────┐
│  💡 Hold to fast-forward     │
│     through video            │
└──────────────────────────────┘
```
- Auto-dismisses after 3 seconds or on tap
- Background: ccSurfaceElevated, 12pt corner radius
- Arrow pointing to the skip-forward button
- Only shown once, ever

---

## Export Flow

This is the part where my video becomes a movie star! And then it goes in the camera roll.

### Initiating Export

The **Export button** lives in the bottom-right corner of the screen.

| Property | Value |
|----------|-------|
| **Label** | "Export" |
| **SF Symbol** | `square.and.arrow.up` (leading, 16pt) |
| **Font** | `.headline` Semibold |
| **Background** | Signal Blue (`#0A84FF`) |
| **Corner radius** | 22pt (fully rounded pill) |
| **Size** | 120×44pt |
| **Disabled state** | When no segments are included — alpha 0.4, non-interactive |
| **Haptic on tap** | `.impactOccurred(.medium)` |

### Export Sheet (`.sheet` presentation)

Tapping Export presents a **half-sheet** (`.presentationDetents([.medium])`) with export options:

```
┌──────────────────────────────────────┐
│  ─── (drag indicator)                │
│                                      │
│  Export Video                        │  ← .title2 Bold
│                                      │
│  X segments · X:XX total duration    │  ← .body, ccTextSecondary
│                                      │
│  ┌────────────────────────────────┐  │
│  │  ★ Original Quality            │  │  ← option card
│  │  No re-encoding · Fastest      │  │
│  │  Same file size as source      │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │  ⚡ Smaller File               │  │  ← option card
│  │  Re-encoded · Slower export    │  │
│  │  ~60% of original size         │  │
│  └────────────────────────────────┘  │
│                                      │
│  ╔══════════════════════════════════╗ │
│  ║         Export Now               ║ │  ← primary action button
│  ╚══════════════════════════════════╝ │
│                                      │
└──────────────────────────────────────┘
```

### Export Option Cards

| Property | Value |
|----------|-------|
| **Card background** | ccSurface (`#1A1A24`) |
| **Card background (selected)** | Signal Blue at 10% opacity |
| **Border (selected)** | 2pt solid Signal Blue (`#0A84FF`) |
| **Border (unselected)** | 1pt solid ccExclude (`#3A3A3C`) |
| **Corner radius** | 14pt |
| **Padding** | 16pt all sides |
| **Title** | `.body` Semibold, ccTextPrimary |
| **Subtitle** | `.caption` Regular, ccTextSecondary |
| **Icon — Original** | `star.fill` · 18pt · Fast Orange (`#FF9F0A`) |
| **Icon — Smaller** | `bolt.fill` · 18pt · Signal Blue (`#0A84FF`) |
| **Selection** | Default: "Original Quality" pre-selected |
| **Haptic on select** | `.selectionChanged()` |

### Export Now Button

| Property | Value |
|----------|-------|
| **Background** | Signal Blue (`#0A84FF`) |
| **Label** | "Export Now" · `.headline` Semibold · White |
| **Corner radius** | 16pt |
| **Height** | 52pt |
| **Width** | Full width minus 32pt horizontal padding |

### Progress State

Once "Export Now" is tapped, the sheet transforms (animated, 0.3s):

```
┌──────────────────────────────────────┐
│  ─── (drag indicator, disabled)      │
│                                      │
│  Exporting…                          │  ← .title2 Bold
│                                      │
│       ┌─────────────────────────┐    │
│       │ ████████░░░░░░░░░░░░░░░ │    │  ← progress bar
│       └─────────────────────────┘    │
│            34%  ·  12s remaining     │  ← .body, ccTextSecondary
│                                      │
│          [Cancel Export]             │  ← text button, Court Red
│                                      │
└──────────────────────────────────────┘
```

| Property | Value |
|----------|-------|
| **Progress bar height** | 8pt |
| **Progress bar corner radius** | 4pt |
| **Progress fill color** | Signal Blue (`#0A84FF`) |
| **Progress track color** | ccSurface (`#1A1A24`) |
| **Animation** | Progress bar fills with `.linear` animation tracking actual progress |
| **Cancel button** | `.body` Regular, Court Red (`#FF453A`) — presents confirmation alert |
| **Sheet dismiss** | Disabled during export (`.interactiveDismissDisabled(true)`) |

### Completion State

```
┌──────────────────────────────────────┐
│                                      │
│            ✓                         │  ← animated checkmark (see micro-interactions)
│                                      │
│  Saved to Camera Roll               │  ← .title2 Bold
│                                      │
│  2:34 of highlights from            │  ← .body, ccTextSecondary
│  35:20 of footage                   │
│                                      │
│  ╔══════════════════════════════════╗ │
│  ║           Done                   ║ │  ← primary button, Rally Green bg
│  ╚══════════════════════════════════╝ │
│                                      │
│         Share Video                  │  ← text button, Signal Blue
│                                      │
└──────────────────────────────────────┘
```

| Property | Value |
|----------|-------|
| **Checkmark** | SF Symbol `checkmark.circle.fill` · 56pt · Rally Green (`#30D158`) |
| **Checkmark animation** | Scale from 0→1.1→1.0 with bounce (0.5s spring), then a confetti-like particle burst (see micro-interactions) |
| **Done button** | Rally Green background, white label, same dimensions as Export Now |
| **Share button** | Text-only, Signal Blue, opens system share sheet via `UIActivityViewController` |
| **Haptic** | `.notificationOccurred(.success)` on completion |
| **Auto-dismiss** | No — user must tap Done or Share |

---

## Empty State

When there's no video, the screen looks like my drawing of a horse! But better.

### Layout

```
┌──────────────────────────────────────┐
│                                      │
│                                      │
│                                      │
│           📹                          │  ← SF Symbol, large
│                                      │
│      Tap to open a video             │  ← headline
│                                      │
│   Pick a game film from your         │  ← body
│   camera roll and start clipping     │
│                                      │
│   ╔══════════════════════════════╗   │
│   ║    Choose Video              ║   │  ← primary action
│   ╚══════════════════════════════╝   │
│                                      │
│                                      │
└──────────────────────────────────────┘
```

| Property | Value |
|----------|-------|
| **Icon** | `video.badge.plus` · 56pt · ccTextSecondary (`#8E8E93`) |
| **Headline** | "Tap to open a video" · `.title2` Bold · ccTextPrimary |
| **Body** | "Pick a game film from your camera roll and start clipping" · `.body` Regular · ccTextSecondary |
| **Button** | "Choose Video" · Signal Blue bg · white label · 52pt tall · 200pt wide · 16pt corner radius |
| **Alignment** | All centered, vertically centered in safe area |
| **Spacing** | Icon → Headline: 16pt · Headline → Body: 8pt · Body → Button: 24pt |

### Tapping Anywhere

The entire empty-state view is tappable (in addition to the button) — triggers photo picker. This is forgiving design.

---

## Auto-Save & Resume

If my phone falls asleep, my video doesn't forget where it is! Like how I always remember where I left my paste.

### Resume Banner

When the app launches with a saved session, show a **non-modal banner** at the top of the video player area:

```
┌──────────────────────────────────────┐
│  ↩ Resume editing "IMG_4521.MOV"?    │
│  [Continue]          [Start Fresh]   │
└──────────────────────────────────────┘
```

| Property | Value |
|----------|-------|
| **Background** | ccSurfaceElevated (`#252533`) at 95% opacity + blur |
| **Corner radius** | 14pt |
| **Padding** | 16pt |
| **Icon** | `arrow.uturn.backward.circle.fill` · 20pt · Signal Blue |
| **Text** | `.body` Regular · ccTextPrimary |
| **Continue button** | `.body` Semibold · Signal Blue |
| **Start Fresh button** | `.body` Regular · ccTextSecondary |
| **Animation** | Slides down from top, 0.4s spring |
| **Auto-dismiss** | After 10 seconds → defaults to resume behavior |

---

## Micro-interactions & Delight

These are the sprinkles! I like sprinkles on my ice cream AND my apps.

### 1. Toggle Ripple Effect

When the toggle is tapped ON:
- A subtle **radial ripple** emanates from the tap point outward across the button
- Color: Rally Green at 20% opacity
- Duration: 0.4s, ease-out, fades to 0
- Implemented via `Canvas` or custom `Shape` animation

### 2. Segment Growth Animation

When a new included segment is being recorded (toggle is ON and video is playing):
- The current segment on the timeline **grows in real-time** from left to right
- Rally Green fills progressively, like paint being applied
- This is the most satisfying visual in the app — you can SEE your highlights being built

### 3. Export Checkmark Celebration

On export completion:
1. Checkmark scales in with spring bounce (0→1.1→1.0, 0.5s)
2. Small **particle burst** — 12-16 tiny circles in Rally Green and Signal Blue
   - Particles radiate outward 40-60pt from center
   - Each particle: 4pt circle, random trajectory, 0.6s duration, fades out
   - Staggered start: 0-0.1s random delay per particle
3. Haptic: `.notificationOccurred(.success)`

### 4. Video Load Transition

When a video is selected from the picker:
- Empty state **fades out** (0.2s)
- Video player **fades in** from black (0.3s)
- Controls slide up from below (0.4s spring, staggered: timeline first, then controls, then toggle)
- First-time tooltip for toggle appears after 1s delay (see below)

### 5. First-Time Toggle Tooltip

On first ever video load (UserDefaults flag):

```
┌──────────────────────────────┐
│  Tap when you see a play     │
│  you want to keep            │
│            ↓                 │
└──────────────────────────────┘
         [● TOGGLE BUTTON]
```

- Background: ccSurfaceElevated, 12pt corner radius, 8pt vertical shadow
- Arrow pointing down to toggle button
- Auto-dismisses on first toggle tap, or after 5 seconds
- Never shown again

### 6. Speed Change Feedback

When changing playback speed:
- Brief overlay in center of video: speed value in Fast Orange, `.largeTitle` Bold
- Fades in 0.1s, holds 0.5s, fades out 0.3s
- SF Symbol `gauge.with.needle.fill` beside the value

### 7. Haptic Palette Summary

| Action | Haptic Pattern |
|--------|---------------|
| Toggle ON | `.impact(.medium)` + 50ms + `.impact(.light)` |
| Toggle OFF | `.impact(.light)` |
| Play/Pause | `.selectionChanged()` |
| Speed change | `.selectionChanged()` |
| Skip fwd/back | `.impact(.light)` |
| FF engage | `.impact(.rigid)` |
| FF release | `.impact(.soft)` |
| Export tap | `.impact(.medium)` |
| Export complete | `.notification(.success)` |
| Segment tap (timeline) | `.impact(.light)` |
| Scrub bar drag | continuous `.selectionChanged()` every 0.5s of playback time |

---

## Accessibility

Everyone gets to use ClipCourt! My friend who uses the talking phone thinks it's neat.

### VoiceOver Labels

| Element | Label | Hint | Traits |
|---------|-------|------|--------|
| **Toggle (OFF)** | "Include toggle, off" | "Double tap to start including current video segment" | `.isToggle` |
| **Toggle (ON)** | "Include toggle, on, recording" | "Double tap to stop including current video segment" | `.isToggle` |
| **Play button** | "Play" / "Pause" | "Double tap to play/pause video" | `.isButton` |
| **Skip Back** | "Skip back 15 seconds" | "Double tap to skip back. Hold to rewind." | `.isButton` |
| **Skip Forward** | "Skip forward 15 seconds" | "Double tap to skip forward. Hold to fast-forward." | `.isButton` |
| **Speed selector** | "Playback speed, currently 1x" | "Double tap to change playback speed" | `.isButton` |
| **Scrub bar** | "Playback position, 12 minutes 34 seconds of 35 minutes 20 seconds" | "Swipe up or down to seek" | `.isAdjustable` |
| **Segment timeline** | "Segment timeline, 3 included segments, 4 excluded segments" | "Double tap to jump to a segment" | `.isButton` |
| **Export button** | "Export video" | "Double tap to open export options" | `.isButton` |
| **Export (disabled)** | "Export video, no segments included" | "Include segments by using the toggle during playback" | `.isButton`, `.notEnabled` |

### VoiceOver Announcements (`.accessibilityAnnouncement`)

| Event | Announcement |
|-------|-------------|
| Toggle ON | "Now recording — included segments will be kept" |
| Toggle OFF | "Stopped recording" |
| Export started | "Exporting video" |
| Export progress | "Export {percent} percent complete" (announced at 25%, 50%, 75%) |
| Export complete | "Export complete. Video saved to camera roll." |
| Speed change | "Playback speed {value}x" |

### Dynamic Type

All text uses **system text styles** (`.body`, `.headline`, `.caption`, etc.) via SwiftUI's `Font.system()` — this automatically supports Dynamic Type.

**Layout adjustments at larger sizes:**
- At **AX3 and above**: Playback controls wrap to two rows (skip buttons on top, play/pause + speed on bottom)
- At **AX5 and above**: Toggle button label wraps to two lines if needed; minimum button height increases to 88pt
- Segment timeline maintains fixed height (it's a visual element, not text-dependent)
- Timestamps use SF Mono but still scale with Dynamic Type

### Color Contrast

All color pairings meet **WCAG 2.1 AA** (minimum 4.5:1 for text, 3:1 for large text and UI components):

| Foreground | Background | Ratio | Passes |
|------------|------------|-------|--------|
| Snow (`#F2F2F7`) | Midnight (`#0A0A0F`) | 17.4:1 | ✅ AAA |
| Mist (`#8E8E93`) | Midnight (`#0A0A0F`) | 5.5:1 | ✅ AA |
| Rally Green (`#30D158`) | Midnight (`#0A0A0F`) | 8.9:1 | ✅ AAA |
| Rally Green (`#30D158`) | Charcoal (`#1A1A24`) | 6.8:1 | ✅ AA |
| Signal Blue (`#0A84FF`) | Midnight (`#0A0A0F`) | 5.1:1 | ✅ AA |
| Court Red (`#FF453A`) | Midnight (`#0A0A0F`) | 5.2:1 | ✅ AA |
| Fast Orange (`#FF9F0A`) | Midnight (`#0A0A0F`) | 8.0:1 | ✅ AAA |
| Ink (`#1C1C1E`) | Paper (`#FFFFFF`) | 16.8:1 | ✅ AAA (light mode) |

### Reduce Motion

When `UIAccessibility.isReduceMotionEnabled`:
- Toggle ripple effect → instant color change (no ripple)
- Export celebration particles → no particles, just checkmark fade-in (0.2s)
- Segment growth → segments still grow but without animation (step updates)
- All spring animations → replaced with 0.2s linear transitions
- Video player border glow pulse → static glow (no pulse)

### Button Shapes

When `UIAccessibility.buttonShapesEnabled`:
- All interactive buttons get visible underlines or outlines
- Toggle button always shows its border (even in OFF state, the border becomes more prominent: 2pt → 3pt)

---

## SF Symbols Reference

These are all the little pictures! I collected them like Pokémon.

| Usage | Symbol Name | Rendering | Weight |
|-------|-------------|-----------|--------|
| Toggle OFF | `circle` | Monochrome | Regular |
| Toggle ON | `record.circle` | Monochrome, Rally Green | Regular |
| Play | `play.fill` | Monochrome | Regular |
| Pause | `pause.fill` | Monochrome | Regular |
| Skip Back | `gobackward.15` | Monochrome | Regular |
| Skip Forward | `goforward.15` | Monochrome | Regular |
| Fast Forward (held) | `forward.fill` | Monochrome, Fast Orange | Regular |
| Speed selector | `gauge.with.needle.fill` | Monochrome | Regular |
| Export | `square.and.arrow.up` | Monochrome | Regular |
| Export Original | `star.fill` | Monochrome, Fast Orange | Regular |
| Export Smaller | `bolt.fill` | Monochrome, Signal Blue | Regular |
| Export Complete | `checkmark.circle.fill` | Monochrome, Rally Green | Regular |
| Empty State | `video.badge.plus` | Hierarchical | Regular |
| Resume | `arrow.uturn.backward.circle.fill` | Monochrome, Signal Blue | Regular |
| Share | `square.and.arrow.up` | Monochrome, Signal Blue | Regular |

---

## Appendix: Dimension Summary

My ruler goes up to 12 inches! But these are in points.

### Portrait (iPhone)

| Element | Width | Height | Margin/Padding |
|---------|-------|--------|----------------|
| Video Player | 100% | Aspect-fit (16:9 → ~209pt on iPhone 15) | 0pt |
| Status Row | 100% | 36pt | H: 16pt |
| Scrub Bar | 100% - 32pt | 44pt (tap), 4-8pt (visual) | H: 16pt |
| Segment Timeline | 100% - 32pt | 48pt | H: 16pt, V: 4pt |
| Controls Row | 100% - 32pt | 52pt | H: 16pt |
| Toggle Button | 100% - 32pt | 72pt | H: 16pt |
| Export Button | 120pt | 44pt | 16pt from right, 16pt from safe area bottom |

### Landscape (iPhone)

| Element | Width | Height |
|---------|-------|--------|
| Video Player | ~70% of width | Fill available above bottom strip |
| Right Panel | ~30% of width | Full height minus bottom strip |
| Bottom Strip | 100% | 80pt (44pt scrub + 36pt timeline) |
| Toggle Button (landscape) | Panel width - 32pt | 56pt |

### Common

| Property | Value |
|----------|-------|
| Corner radius (buttons) | 16pt (rect) or 22pt (pill) |
| Corner radius (cards) | 14pt |
| Corner radius (timeline bar) | 8pt |
| Corner radius (sheets) | System default |
| Minimum tap target | 44×44pt |
| Standard horizontal padding | 16pt |
| Animation default | `.spring(response: 0.35, dampingFraction: 0.75)` |

---

## Design Revision History

| Date | Version | Notes |
|------|---------|-------|
| 2025-07-12 | 1.0 | Initial design document — Designer Ralph 🎨 |

---

> "When I grow up, I want to be a principal — or a caterpillar."
>
> But for now, I'm a designer. And this design is done. It goes in my pocket for safekeeping! 🖍️
