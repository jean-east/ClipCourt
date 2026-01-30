# ClipCourt — Bug Tracker

> Managed by Ralph PM. Engineers pick up from here.

## Format
| ID | Priority | Status | Title | Filed By | Assigned To | Notes |
|----|----------|--------|-------|----------|-------------|-------|
<!-- P0=critical P1=major P2=minor P3=cosmetic -->
<!-- Status: open | in-progress | fixed | verified | wontfix -->

---

## 🏁 TestFlight Readiness Summary

**✅ No P0/P1 blockers — ready for TestFlight.**

The app is functionally complete — video import, playback, toggle, timeline with pinch-to-zoom, landscape layout, export, and persistence all work. BUG-014 (P1 data-loss blocker) has been fixed (`bce7bf5`).

**Remaining: 0 blockers + 5 P2 (polish) + 3 P3 (cosmetic) = 8 open bugs.**

### Recommended Fix Order (pre-TestFlight polish)
1. **BUG-013** (P2, Boss-filed) — Close button confirmation dialog. Safety-critical UX.
2. **BUG-010** (P3, quick win) — Two green shades. Boss-filed, easy 5-min fix.
3. **BUG-011** (P2, new) — Landscape missing "included duration" text. Easy add.
4. **BUG-009** (P3, quick win) — Constants mismatch. 2-min cleanup.
5. **BUG-006** (P2) — Full-area tap on import. Forgiving design.
6. **BUG-007** (P2) — Custom scrub bar. Significant design spec delta.
7. **BUG-012** (P3, new) — Animation/layout trigger mismatch. Minor inconsistency.

### Defer to Post-TestFlight
- **BUG-004** (P2) — Light mode. Design says "dark first." Gym/court users → dark is fine.
- **BUG-008** (P3) — Custom speed pill picker. System Menu works fine.

---

## Open Bugs

### P1 — Major / Broken Feature

#### BUG-014: Existing segments silently disappear when recording a new segment (data loss) ✅ FIXED
- **Priority:** P1
- **Status:** fixed
- **Filed:** 2025-07-14 (Boss)
- **File(s):** `Services/SegmentManager.swift` → `beginIncluding()`, `splitAndSetIncluded()`, `cleanup()`
- **Description:** When a user creates an included segment (e.g., at the end of a video), then seeks to a different position and records a new segment, the original segment silently disappears. This is a data-loss bug — the user's previously created work is destroyed without warning.
- **Steps to Reproduce:**
  1. Start editing a video.
  2. Seek to the end, toggle ON to start recording, toggle OFF to finish → creates an included segment near the end.
  3. Seek to the beginning, toggle ON to start recording a new segment.
  4. Toggle OFF to finish the new segment.
  5. **Observe:** The segment created in step 2 has vanished from the timeline.
- **Root Cause (code-traced):**
  The bug is a lossy merge during `beginIncluding()`. Here's the exact chain (using a 60s video as example):
  1. After step 2, segments are: `[Seg(0,55,excl), Seg(55,58,incl), Seg(58,60,excl)]` ✅
  2. Step 3 calls `beginIncluding(at:0, videoDuration:60)`. `segmentIndex(containing:0)` finds index 0 → `Seg(0,55,excl)`.
  3. `splitAndSetIncluded(at:0, index:0, setIncluded:true)` — since `time (0) <= original.startTime (0)`, the **entire** segment `Seg(0,55)` is flipped to included (no split occurs at a boundary).
  4. `cleanup()` → `mergeAdjacentSegments()` sees `Seg(0,55,incl)` adjacent to `Seg(55,58,incl)` → **merges** into `Seg(0,58,incl)`. The boundary at t=55 is destroyed.
  5. Step 4 calls `stopIncluding(at:3)` → splits `Seg(0,58,incl)` into `Seg(0,3,incl)` + `Seg(3,58,excl)`. The `Seg(3,58,excl)` merges with `Seg(58,60,excl)` → `Seg(3,60,excl)`.
  6. Final segments: `[Seg(0,3,incl), Seg(3,60,excl)]` — the user's segment at 55–58 **no longer exists**.
  
  **In short:** `beginIncluding()` calls `cleanup()` which calls `mergeAdjacentSegments()`. The newly-included portion merges with the adjacent pre-existing included segment, creating one large "super-segment." When `stopIncluding()` later splits this super-segment, everything after the split becomes excluded — silently erasing the original segment.
  
  This is **not** limited to seeking to t=0. It reproduces whenever `beginIncluding` creates an included region adjacent to an existing included segment (e.g., seeking to t=1 inside the same excluded segment triggers the same merge).
- **Expected:** Creating a new included segment should never destroy existing included segments. All previously recorded segments must be preserved.
- **Fix Direction (PM recommendation — engineer to validate):**
  - **Option A (minimal):** In `beginIncluding()`, replace `cleanup()` with a limited cleanup that removes zero-duration segments and sorts, but **skips `mergeAdjacentSegments()`**. Defer merging to `stopIncluding()`, `toggleSegment()`, and `finalizeSegments()`. This preserves segment boundaries during an active recording. Adjacent same-state segments temporarily coexist — they merge when the recording closes.
  - **Option B (structural):** Change `beginIncluding()` so that the new included region only extends to the **next segment boundary** (not the end of the current excluded segment). This avoids creating the adjacent same-state condition entirely. E.g., if segments are `[Seg(0,55,excl), Seg(55,58,incl), ...]` and user begins at t=0, create `[Seg(0,55,incl), Seg(55,58,incl), ...]` — which would still merge. So Option A is likely cleaner.
  - **Option C (hybrid):** Add a "recording origin" marker to SegmentManager. During cleanup, never merge a segment that was just created by `beginIncluding` with pre-existing segments. Clear the marker on `stopIncluding`.
- **PM Note:** This is the highest-priority bug. It's a silent data-loss issue — no error, no warning, the user's work simply vanishes. Blocks TestFlight.

---

### P2 — Minor / Polish

#### BUG-004: Colors not adaptive — no light mode support
- **Priority:** P2
- **Status:** open → **deferred post-TestFlight**
- **Filed:** 2025-07-13 (PM code review + QA screenshot)
- **File(s):** `Utilities/Color+ClipCourt.swift`, `Assets.xcassets/`
- **Description:** All colors in Color+ClipCourt.swift are hardcoded RGB values (dark mode only). Design.md includes a full light mode palette (Paper #FFFFFF background, Cloud #F2F2F7 surface, etc.). QA screenshot confirms app stays fully dark when system is in light mode.
- **Expected:** Colors should use asset catalog adaptive colors or `Color(UIColor { traitCollection in ... })` to switch between dark and light palettes.
- **PM Note:** Design.md says "Dark-first... Light mode supported but dark is default and primary." Target audience (gym/court users) almost always in dark mode. Safe to defer.

#### BUG-005: No resume banner on session restore
- **Priority:** P2
- **Status:** wontfix
- **Filed:** 2025-07-13 (PM code review)
- **Closed:** 2025-07-13 (Boss — not needed, auto-resume is fine)
- **File(s):** `ClipCourtApp.swift` (ContentView), `Views/PlayerView.swift`
- **Description:** Design.md specifies a slide-down resume banner. Current code auto-resumes immediately without asking.
- **Resolution:** Boss says resume state isn't needed. Auto-resume behavior is acceptable.

#### BUG-013: No confirmation dialog when tapping Close button ⭐ NEW
- **Priority:** P2
- **Status:** open
- **Filed:** 2025-07-13 (Boss)
- **File(s):** `Views/PlayerView.swift`
- **Description:** Tapping the Close button (in the export bar) exits the editing session immediately with no confirmation. User could lose their work accidentally.
- **Expected:** Show a confirmation dialog (e.g., "Discard edits? [Cancel] [Discard]") before closing the session.
- **Fix:** Add a `.confirmationDialog` or `.alert` modifier triggered by the close button tap.

#### BUG-006: Empty state not fully tappable
- **Priority:** P2
- **Status:** open
- **Filed:** 2025-07-13 (PM code review)
- **File(s):** `Views/ImportView.swift`
- **Description:** Design.md says "The entire empty-state view is tappable (in addition to the button) — triggers photo picker." ImportView has `.contentShape(Rectangle())` but no tap gesture on the full view. Only the `PhotosPicker` button opens the picker. The `.contentShape` alone doesn't help — needs a programmatic way to trigger the picker, which is tricky with SwiftUI's `PhotosPicker`.
- **Expected:** Tapping anywhere on the empty state should open the photo picker.
- **PM Note:** May require wrapping in UIViewControllerRepresentable for PHPickerViewController to get programmatic trigger. Non-trivial.

#### BUG-007: Scrub bar not custom-styled per Design.md
- **Priority:** P2
- **Status:** open
- **Filed:** 2025-07-13 (PM code review)
- **File(s):** `Views/PlayerView.swift`
- **Description:** Uses a stock SwiftUI `Slider` instead of the custom scrub bar specified in Design.md (4pt track expanding to 8pt on drag, Snow color at 80% elapsed, frame preview thumbnails on drag, SF Mono timestamps on each side).
- **Expected:** Custom scrub bar matching Design.md spec.
- **PM Note:** Frame preview thumbnails are a significant feature (AVAssetImageGenerator). Consider a phased approach: custom track styling first, thumbnails as a fast-follow.

#### BUG-011: Landscape export bar missing "included duration" text ⭐ NEW
- **Priority:** P2
- **Status:** open
- **Filed:** 2025-07-13 (PM review of 82e4ae9 landscape rework)
- **File(s):** `Views/PlayerView.swift` → `landscapeExportButton`
- **Description:** The portrait `exportBar` shows `"\(TimeFormatter.format(project.includedDuration)) selected"` between the close button and export pill. The landscape `landscapeExportButton` omits this — user can't see how much footage they've selected while in landscape mode.
- **Expected:** Show included duration in landscape export area (possibly compact, e.g., just the time string).
- **Fix:** Add the duration text to `landscapeExportButton`. ~5 lines.

---

### P3 — Cosmetic

#### BUG-008: Speed selector uses system Menu instead of custom pill picker
- **Priority:** P3
- **Status:** open → **deferred post-TestFlight**
- **Filed:** 2025-07-13 (PM code review)
- **File(s):** `Views/PlayerView.swift`
- **Description:** Design.md specifies a custom inline pill picker that slides up from the speed button. Current implementation uses SwiftUI `Menu` which renders as a system context menu. Functionally equivalent but doesn't match design spec.
- **Expected:** Custom slide-up pill picker per Design.md.

#### BUG-009: Constants.UI.timelineHeight mismatch
- **Priority:** P3
- **Status:** open
- **Filed:** 2025-07-13 (PM code review)
- **File(s):** `Utilities/Constants.swift`, `Views/PlayerView.swift`
- **Description:** `Constants.UI.timelineHeight` is set to 60pt but PlayerView uses `.frame(height: 48)` (portrait) and `.frame(height: 36)` (landscape). The constant is misleading and unused.
- **Expected:** Either update constant to 48 and add a `timelineHeightLandscape = 36`, or remove and use magic numbers with comments. Use constants in PlayerView instead of raw numbers.
- **Fix:** 2-minute cleanup.

#### BUG-010: Two different shades of green on segment timeline
- **Priority:** P3
- **Status:** open
- **Filed:** 2025-07-13 (Boss — visual report)
- **File(s):** `Views/SegmentTimelineView.swift`, `Utilities/Color+ClipCourt.swift`
- **Description:** Adjacent included segments on the timeline render in two noticeably different shades of green. **Root cause identified:** `segmentFillColor()` in SegmentTimelineView.swift uses `Color.ccIncludeGlow` (#34E060) for the current/active segment and `Color.ccInclude` (#30D158) for others. When two included segments are adjacent and the playhead is on one, the color difference is stark.
- **Screenshot:** Boss-provided — clearly shows lighter and darker green segments side by side.
- **Expected:** All included segments should appear visually consistent. Use a different cue for "current segment" — e.g., brighter border, opacity pulse, or overlay glow — rather than changing the fill color.
- **Fix:** Change `segmentFillColor` to return `Color.ccInclude` for all included segments, and add a subtle overlay or border for the current one. ~10 lines.

#### BUG-015: White/miscolored bars on import screen (top and bottom corners) ⭐ NEW
- **Priority:** P2
- **Status:** open
- **Filed:** 2025-07-13 (Boss — screenshot)
- **File(s):** `Views/ImportView.swift`, `ClipCourtApp.swift`
- **Description:** The import/empty-state screen shows a white bar at the very top (behind the status bar notch area) and a green corner bleed at the bottom right. The app's background color isn't extending edge-to-edge — likely missing `.ignoresSafeArea()` or the window/scene background isn't set to `ccBackground`.
- **Screenshot:** Boss-provided — clearly shows white strip at top and green corner at bottom-right on dark import screen.
- **Expected:** `ccBackground` (#0A0A0F) should fill the entire screen edge-to-edge including behind the status bar and home indicator areas. No color bleed from other views.
- **Fix:** Ensure the root view or NavigationStack has `.background(Color.ccBackground.ignoresSafeArea())`. Check if any underlying view (like a green accent) is bleeding through at the bottom corner.

#### BUG-012: Animation value mismatched with layout trigger ⭐ NEW
- **Priority:** P3
- **Status:** open
- **Filed:** 2025-07-13 (PM review of 82e4ae9 landscape rework)
- **File(s):** `Views/PlayerView.swift`
- **Description:** The `.animation(.easeInOut(duration: 0.35), value: isLandscape)` modifier watches `isLandscape` (computed from `verticalSizeClass`), but the actual layout branch (`if outerProxy.size.width > outerProxy.size.height`) uses GeometryReader aspect ratio. These can fire at different times during rotation, causing the animation to not trigger on layout change, or trigger at the wrong moment.
- **Expected:** Animation value should match the layout trigger. Either both use GeometryReader or both use sizeClass.
- **Fix:** Add a `@State private var isWideLayout: Bool = false` that updates from the GeometryReader, and animate on that value. Or simplify to use `verticalSizeClass` for both.

---

## Fixed / Closed

| ID | Priority | Title | Fixed By | Commit |
|----|----------|-------|----------|--------|
| — | P1 | Share Video button was a stub | Engineer | `ceb4a35` |
| BUG-001 | P1 | No end-of-video handling | PM Ralph | `bcf84d0` |
| BUG-002 | P1 | No landscape-adaptive layout | PM Ralph + Engineer | `cf12848` → `82e4ae9` |
| BUG-003 | P1 | Pinch-to-zoom timeline | PM Ralph | `b342358` |
| BUG-014 | P1 | Segments silently disappear (data loss) | Engineer | `bce7bf5` |

---

## Process
1. **Boss or QA** files a bug → added here
2. **PM** triages (assigns priority, dedupes, clarifies)
3. **PM** assigns to Engineer Ralph for fix
4. **Engineer** fixes, commits, updates status
5. **PM** verifies fix, closes bug
