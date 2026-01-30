# ClipCourt — Bug Tracker

> Managed by Ralph PM. Engineers pick up from here.

## Format
| ID | Priority | Status | Title | Filed By | Assigned To | Notes |
|----|----------|--------|-------|----------|-------------|-------|
<!-- P0=critical P1=major P2=minor P3=cosmetic -->
<!-- Status: open | in-progress | fixed | verified | wontfix -->

## Open Bugs

### P1 — Major / Broken Feature

#### BUG-001: No end-of-video handling — isPlaying stuck, segment not finalized
- **Priority:** P1
- **Status:** ✅ fixed (bcf84d0)
- **Filed:** 2025-07-13 (PM code review)
- **File(s):** `ViewModels/PlayerViewModel.swift`
- **Description:** PlayerViewModel never subscribes to `VideoPlayerService.didPlayToEndPublisher`. When playback reaches the end of the video:
  1. `isPlaying` remains `true` in the UI even though AVPlayer auto-paused (per `player.actionAtItemEnd = .pause`)
  2. If the user had toggle ON (including), the segment is never explicitly closed at the video's end time
  3. The play/pause button shows "pause" icon when nothing is playing — confusing UX
- **Expected:** When video reaches end, `isPlaying` should flip to `false`, and if the user was including, `stopIncluding(at: duration)` should be called to close the open segment. Optionally seek back to start for replay.
- **Repro:** Load any video, play to end, observe the play/pause button still shows pause icon.

#### BUG-002: No landscape-adaptive layout
- **Priority:** P1
- **Status:** ✅ fixed (cf12848 → improved in 82e4ae9)
- **Filed:** 2025-07-13 (PM code review + QA screenshot + Boss re-filed)
- **File(s):** `Views/PlayerView.swift`
- **Description:** PlayerView used a single `VStack` layout that didn't adapt to landscape orientation. The Design.md specifies a 70/30 split landscape layout. Boss re-filed after seeing old build; screenshot at `/tmp/clipcourt-landscape.png` shows portrait VStack rotated sideways.
- **Fix (v1, cf12848):** Added `verticalSizeClass` detection + landscape HStack layout
- **Fix (v2, 82e4ae9):** Improved to use `GeometryReader` aspect ratio detection (`width > height`), scrollable right panel, compact 48pt toggle. All controls in right panel ScrollView.
- **Current state:** Fixed. Video fills left 70%, scrollable controls panel on right 30%. Builds clean.

#### BUG-003: Pinch-to-zoom not implemented on segment timeline
- **Priority:** P1
- **Status:** ✅ fixed (b342358)
- **Filed:** 2025-07-13 (PM code review, also noted in HANDOFF.md)
- **File(s):** `Views/SegmentTimelineView.swift`
- **Description:** SegmentTimelineView has no `MagnificationGesture`, no zoom state, no horizontal scrolling. For a 40-minute video on iPhone, each second is ~0.14pt wide at 1x — segments are effectively untappable. The Design.md calls this feature "critical" and specifies:
  - Pinch-to-zoom (1x–10x range)
  - Horizontal scrolling when zoomed in
  - Auto-follow playhead during playback
  - Snap-to-overview below 1.2x
  - Zoom level indicator badge
  - HANDOFF.md flagged: "SegmentTimelineView.swift is only 70 lines — pinch-to-zoom may not have been fully implemented"
- **Expected:** Full pinch-to-zoom per Design.md spec.
- **Scope:** Large — requires ScrollViewReader, MagnificationGesture, zoom state, auto-follow logic.

---

### P2 — Minor / Polish

#### BUG-004: Colors not adaptive — no light mode support
- **Priority:** P2
- **Status:** open
- **Filed:** 2025-07-13 (PM code review + QA screenshot)
- **File(s):** `Utilities/Color+ClipCourt.swift`, `Assets.xcassets/`
- **Description:** All colors in Color+ClipCourt.swift are hardcoded RGB values (dark mode only). Design.md includes a full light mode palette (Paper #FFFFFF background, Cloud #F2F2F7 surface, etc.). QA screenshot confirms app stays fully dark when system is in light mode.
- **Expected:** Colors should use asset catalog adaptive colors or `Color(UIColor { traitCollection in ... })` to switch between dark and light palettes.
- **Note:** Design.md says "Dark-first... Light mode supported but dark is default and primary." Low priority since target users are in gyms/courts.

#### BUG-005: No resume banner on session restore
- **Priority:** P2
- **Status:** open
- **Filed:** 2025-07-13 (PM code review)
- **File(s):** `ClipCourtApp.swift` (ContentView), `Views/PlayerView.swift`
- **Description:** Design.md specifies a slide-down resume banner: "Resume editing 'IMG_4521.MOV'? [Continue] [Start Fresh]" with auto-dismiss after 10s. Current code auto-resumes immediately without asking.
- **Expected:** Show resume banner per Design.md spec.

#### BUG-006: Empty state not fully tappable
- **Priority:** P2
- **Status:** open
- **Filed:** 2025-07-13 (PM code review)
- **File(s):** `Views/ImportView.swift`
- **Description:** Design.md says "The entire empty-state view is tappable (in addition to the button) — triggers photo picker." ImportView has `.contentShape(Rectangle())` but no tap gesture on the full view. Only the `PhotosPicker` button opens the picker. This is a "forgiving design" requirement.
- **Expected:** Tapping anywhere on the empty state should open the photo picker.

#### BUG-007: Scrub bar not custom-styled per Design.md
- **Priority:** P2
- **Status:** open
- **Filed:** 2025-07-13 (PM code review)
- **File(s):** `Views/PlayerView.swift`
- **Description:** Uses a stock SwiftUI `Slider` instead of the custom scrub bar specified in Design.md (4pt track expanding to 8pt on drag, Snow color at 80% elapsed, frame preview thumbnails on drag, SF Mono timestamps on each side).
- **Expected:** Custom scrub bar matching Design.md spec.

---

### P3 — Cosmetic

#### BUG-008: Speed selector uses system Menu instead of custom pill picker
- **Priority:** P3
- **Status:** open
- **Filed:** 2025-07-13 (PM code review)
- **File(s):** `Views/PlayerView.swift`
- **Description:** Design.md specifies a custom inline pill picker that slides up from the speed button. Current implementation uses SwiftUI `Menu` which renders as a system context menu. Functionally equivalent but doesn't match design spec.
- **Expected:** Custom slide-up pill picker per Design.md.

#### BUG-010: Two different shades of green on segment timeline
- **Priority:** P3
- **Status:** open
- **Filed:** 2025-07-13 (Boss — visual report)
- **File(s):** `Views/SegmentTimelineView.swift`, `Utilities/Color+ClipCourt.swift`
- **Description:** Adjacent included segments on the timeline render in two noticeably different shades of green. Should be one consistent Rally Green (#30D158) across all included segments. Likely one segment uses `Color.ccInclude` and another uses a different green (possibly `.green` system color or an opacity variant).
- **Screenshot:** Boss-provided — clearly shows lighter and darker green segments side by side on the timeline.
- **Expected:** All included segments should be the same Rally Green (#30D158) with uniform appearance.

#### BUG-009: Constants.UI.timelineHeight mismatch
- **Priority:** P3
- **Status:** open
- **Filed:** 2025-07-13 (PM code review)
- **File(s):** `Utilities/Constants.swift`, `Views/PlayerView.swift`
- **Description:** `Constants.UI.timelineHeight` is set to 60pt but PlayerView uses `.frame(height: 48)` which matches Design.md. The constant is misleading / unused.
- **Expected:** Constant should be 48 (portrait) or removed. Use constant in PlayerView instead of magic number.

---

## Fixed / Closed

| ID | Priority | Title | Fixed By | Commit |
|----|----------|-------|----------|--------|
| — | P1 | Share Video button was a stub | Engineer | `ceb4a35` |
| BUG-001 | P1 | No end-of-video handling | PM Ralph | `bcf84d0` |
| BUG-002 | P1 | No landscape-adaptive layout | PM Ralph + Engineer | `cf12848` → `82e4ae9` |
| BUG-003 | P1 | Pinch-to-zoom timeline | PM Ralph | `b342358` |

---

## Process
1. **Boss or QA** files a bug → added here
2. **PM** triages (assigns priority, dedupes, clarifies)
3. **PM** assigns to Engineer Ralph for fix
4. **Engineer** fixes, commits, updates status
5. **PM** verifies fix, closes bug
