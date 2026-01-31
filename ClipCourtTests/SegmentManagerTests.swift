// SegmentManagerTests.swift
// ClipCourtTests
//
// Unit tests for SegmentManager — all 22 test cases from the spec,
// plus additional stress/edge-case tests added during code review.
// Each test exercises beginIncluding/stopIncluding/toggleSegment and
// asserts segment layout + totalIncludedDuration after each stable state.

import XCTest
@testable import ClipCourt

@MainActor
final class SegmentManagerTests: XCTestCase {

    let videoDuration = 10.0

    // MARK: - Helper

    private func assertSegments(
        _ manager: SegmentManager,
        expected: [(start: Double, end: Double, kept: Bool)],
        keptDuration: Double,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            manager.segments.count, expected.count,
            "Segment count mismatch: got \(manager.segments.count), expected \(expected.count). "
            + "Segments: \(manager.segments.map { "[\(String(format: "%.1f", $0.startTime))-\(String(format: "%.1f", $0.endTime)) \($0.isIncluded ? "kept" : "cut")]" })",
            file: file, line: line
        )
        for (i, exp) in expected.enumerated() {
            guard i < manager.segments.count else { continue }
            let seg = manager.segments[i]
            XCTAssertEqual(seg.startTime, exp.start, accuracy: 0.01,
                           "Segment \(i) startTime", file: file, line: line)
            XCTAssertEqual(seg.endTime, exp.end, accuracy: 0.01,
                           "Segment \(i) endTime", file: file, line: line)
            XCTAssertEqual(seg.isIncluded, exp.kept,
                           "Segment \(i) isIncluded — expected \(exp.kept), got \(seg.isIncluded)",
                           file: file, line: line)
        }
        XCTAssertEqual(manager.totalIncludedDuration, keptDuration, accuracy: 0.01,
                       "keptDuration", file: file, line: line)
    }

    // MARK: - Basic Keeping

    /// TC-001: Keep from start, stop in middle
    ///
    /// User starts playing from the beginning, taps keep immediately, watches
    /// until the halfway point, then stops keeping. First half kept, second not.
    func testTC001_keepFromStartStopInMiddle() {
        let m = SegmentManager()

        m.beginIncluding(at: 0, videoDuration: videoDuration)
        // playhead advances to 5, then stop
        m.stopIncluding(at: 5)

        assertSegments(m, expected: [
            (0, 5, true),
            (5, 10, false)
        ], keptDuration: 5.0)
    }

    /// TC-002: Keep from middle, stop before end
    ///
    /// User seeks to 3s, keeps until 7s. Only [3–7] kept.
    func testTC002_keepFromMiddleStopBeforeEnd() {
        let m = SegmentManager()

        m.beginIncluding(at: 3, videoDuration: videoDuration)
        m.stopIncluding(at: 7)

        assertSegments(m, expected: [
            (0, 3, false),
            (3, 7, true),
            (7, 10, false)
        ], keptDuration: 4.0)
    }

    /// TC-003: Keep, stop, keep again (two segments)
    ///
    /// Two non-contiguous kept segments: [2–4] and [6–8].
    func testTC003_keepStopKeepAgain() {
        let m = SegmentManager()

        // First keep [2–4]
        m.beginIncluding(at: 2, videoDuration: videoDuration)
        m.stopIncluding(at: 4)
        assertSegments(m, expected: [
            (0, 2, false),
            (2, 4, true),
            (4, 10, false)
        ], keptDuration: 2.0)

        // Second keep [6–8]
        m.beginIncluding(at: 6, videoDuration: videoDuration)
        m.stopIncluding(at: 8)
        assertSegments(m, expected: [
            (0, 2, false),
            (2, 4, true),
            (4, 6, false),
            (6, 8, true),
            (8, 10, false)
        ], keptDuration: 4.0)
    }

    /// TC-004: Keep all the way to end of video
    ///
    /// Keep starts at 3s, video ends while keeping → auto-finalize.
    func testTC004_keepToEnd() {
        let m = SegmentManager()

        m.beginIncluding(at: 3, videoDuration: videoDuration)
        // videoEnd → stopIncluding at video duration
        m.stopIncluding(at: 10)

        assertSegments(m, expected: [
            (0, 3, false),
            (3, 10, true)
        ], keptDuration: 7.0)
    }

    // MARK: - Re-Keeping

    /// TC-010: Re-keep inside kept segment, stop shorter
    ///
    /// Keep [2–8], then re-keep from 4, stop at 6 → shrinks to [2–6].
    func testTC010_reKeepInsideKeptSegmentStopShorter() {
        let m = SegmentManager()

        // First keep [2–8]
        m.beginIncluding(at: 2, videoDuration: videoDuration)
        m.stopIncluding(at: 8)
        assertSegments(m, expected: [
            (0, 2, false),
            (2, 8, true),
            (8, 10, false)
        ], keptDuration: 6.0)

        // Re-keep from 4, stop at 6 → effective [2–6]
        m.beginIncluding(at: 4, videoDuration: videoDuration)
        m.stopIncluding(at: 6)
        assertSegments(m, expected: [
            (0, 2, false),
            (2, 6, true),
            (6, 10, false)
        ], keptDuration: 4.0)
    }

    /// TC-011: Re-keep spanning two existing kept segments
    ///
    /// Create [2–4] and [6–8], then re-keep [1–9] → one big [1–9] segment.
    func testTC011_reKeepSpanningTwoSegments() {
        let m = SegmentManager()

        // Create [2–4]
        m.beginIncluding(at: 2, videoDuration: videoDuration)
        m.stopIncluding(at: 4)
        assertSegments(m, expected: [
            (0, 2, false),
            (2, 4, true),
            (4, 10, false)
        ], keptDuration: 2.0)

        // Create [6–8]
        m.beginIncluding(at: 6, videoDuration: videoDuration)
        m.stopIncluding(at: 8)
        assertSegments(m, expected: [
            (0, 2, false),
            (2, 4, true),
            (4, 6, false),
            (6, 8, true),
            (8, 10, false)
        ], keptDuration: 4.0)

        // Re-keep from 1 to 9 → swallows both
        m.beginIncluding(at: 1, videoDuration: videoDuration)
        m.stopIncluding(at: 9)
        assertSegments(m, expected: [
            (0, 1, false),
            (1, 9, true),
            (9, 10, false)
        ], keptDuration: 8.0)
    }

    /// TC-012: Re-keep starting in gap between two segments
    ///
    /// Create [1–3] and [7–9], then re-keep from 5 (gap) to 8 →
    /// result: [1–3] and [5–8] kept.
    func testTC012_reKeepStartingInGap() {
        let m = SegmentManager()

        // Create [1–3]
        m.beginIncluding(at: 1, videoDuration: videoDuration)
        m.stopIncluding(at: 3)
        assertSegments(m, expected: [
            (0, 1, false),
            (1, 3, true),
            (3, 10, false)
        ], keptDuration: 2.0)

        // Create [7–9]
        m.beginIncluding(at: 7, videoDuration: videoDuration)
        m.stopIncluding(at: 9)
        assertSegments(m, expected: [
            (0, 1, false),
            (1, 3, true),
            (3, 7, false),
            (7, 9, true),
            (9, 10, false)
        ], keptDuration: 4.0)

        // Re-keep from 5 (gap) to 8 → replaces [7–9] with [5–8]
        m.beginIncluding(at: 5, videoDuration: videoDuration)
        m.stopIncluding(at: 8)
        assertSegments(m, expected: [
            (0, 1, false),
            (1, 3, true),
            (3, 5, false),
            (5, 8, true),
            (8, 10, false)
        ], keptDuration: 5.0)
    }

    /// TC-013: Re-keep starting before all existing segments
    ///
    /// Keep [3–7], then re-keep from 0 to 5 → [0–5] kept.
    func testTC013_reKeepBeforeAll() {
        let m = SegmentManager()

        // Create [3–7]
        m.beginIncluding(at: 3, videoDuration: videoDuration)
        m.stopIncluding(at: 7)
        assertSegments(m, expected: [
            (0, 3, false),
            (3, 7, true),
            (7, 10, false)
        ], keptDuration: 4.0)

        // Re-keep from 0 to 5 → overwrites [3–7]
        m.beginIncluding(at: 0, videoDuration: videoDuration)
        m.stopIncluding(at: 5)
        assertSegments(m, expected: [
            (0, 5, true),
            (5, 10, false)
        ], keptDuration: 5.0)
    }

    /// TC-014: Re-keep spanning three existing kept segments
    ///
    /// Create [1–2], [4–5], [7–8], then re-keep from 0 to 9 → one [0–9] segment.
    func testTC014_reKeepSpanningThreeSegments() {
        let m = SegmentManager()

        // Create [1–2]
        m.beginIncluding(at: 1, videoDuration: videoDuration)
        m.stopIncluding(at: 2)
        assertSegments(m, expected: [
            (0, 1, false),
            (1, 2, true),
            (2, 10, false)
        ], keptDuration: 1.0)

        // Create [4–5]
        m.beginIncluding(at: 4, videoDuration: videoDuration)
        m.stopIncluding(at: 5)
        assertSegments(m, expected: [
            (0, 1, false),
            (1, 2, true),
            (2, 4, false),
            (4, 5, true),
            (5, 10, false)
        ], keptDuration: 2.0)

        // Create [7–8]
        m.beginIncluding(at: 7, videoDuration: videoDuration)
        m.stopIncluding(at: 8)
        assertSegments(m, expected: [
            (0, 1, false),
            (1, 2, true),
            (2, 4, false),
            (4, 5, true),
            (5, 7, false),
            (7, 8, true),
            (8, 10, false)
        ], keptDuration: 3.0)

        // Re-keep from 0 to 9 → swallows all three
        m.beginIncluding(at: 0, videoDuration: videoDuration)
        m.stopIncluding(at: 9)
        assertSegments(m, expected: [
            (0, 9, true),
            (9, 10, false)
        ], keptDuration: 9.0)
    }

    /// TC-015: Re-keep partially overlapping three segments
    ///
    /// Create [1–3], [4–6], [7–9], then re-keep from 2 (inside first) to
    /// 8 (inside third) → all consumed, result [1–8] kept.
    func testTC015_reKeepPartiallyOverlappingThree() {
        let m = SegmentManager()

        // Create [1–3]
        m.beginIncluding(at: 1, videoDuration: videoDuration)
        m.stopIncluding(at: 3)
        assertSegments(m, expected: [
            (0, 1, false),
            (1, 3, true),
            (3, 10, false)
        ], keptDuration: 2.0)

        // Create [4–6]
        m.beginIncluding(at: 4, videoDuration: videoDuration)
        m.stopIncluding(at: 6)
        assertSegments(m, expected: [
            (0, 1, false),
            (1, 3, true),
            (3, 4, false),
            (4, 6, true),
            (6, 10, false)
        ], keptDuration: 4.0)

        // Create [7–9]
        m.beginIncluding(at: 7, videoDuration: videoDuration)
        m.stopIncluding(at: 9)
        assertSegments(m, expected: [
            (0, 1, false),
            (1, 3, true),
            (3, 4, false),
            (4, 6, true),
            (6, 7, false),
            (7, 9, true),
            (9, 10, false)
        ], keptDuration: 6.0)

        // Re-keep from 2 (inside first) to 8 (inside third) → [1–8]
        m.beginIncluding(at: 2, videoDuration: videoDuration)
        m.stopIncluding(at: 8)
        assertSegments(m, expected: [
            (0, 1, false),
            (1, 8, true),
            (8, 10, false)
        ], keptDuration: 7.0)
    }

    // MARK: - Seek + Keep

    /// TC-020: Seek to end, keep, seek to start, keep another
    ///
    /// Keep [7–9], then seek back and keep [2–4]. Two independent regions.
    func testTC020_seekEndKeepThenSeekStartKeep() {
        let m = SegmentManager()

        // Keep [7–9]
        m.beginIncluding(at: 7, videoDuration: videoDuration)
        m.stopIncluding(at: 9)
        assertSegments(m, expected: [
            (0, 7, false),
            (7, 9, true),
            (9, 10, false)
        ], keptDuration: 2.0)

        // Seek back, keep [2–4]
        m.beginIncluding(at: 2, videoDuration: videoDuration)
        m.stopIncluding(at: 4)
        assertSegments(m, expected: [
            (0, 2, false),
            (2, 4, true),
            (4, 7, false),
            (7, 9, true),
            (9, 10, false)
        ], keptDuration: 4.0)
    }

    /// TC-021: Start keeping, seek backward, stop
    ///
    /// Begin keep at 5, scrub backward to 2, stop → [2–5] kept.
    /// (Backward seek during keep uses min/max of start and stop.)
    func testTC021_keepSeekBackwardStop() {
        let m = SegmentManager()

        // Start keeping at 5
        m.beginIncluding(at: 5, videoDuration: videoDuration)
        // Scrub backward to 2, then stop
        m.stopIncluding(at: 2)

        assertSegments(m, expected: [
            (0, 2, false),
            (2, 5, true),
            (5, 10, false)
        ], keptDuration: 3.0)
    }

    /// TC-022: Keep, seek forward past gap, stop
    ///
    /// Begin keep at 2, scrub forward to 8, stop → [2–8] kept.
    func testTC022_keepSeekForwardStop() {
        let m = SegmentManager()

        // Start keeping at 2
        m.beginIncluding(at: 2, videoDuration: videoDuration)
        // Scrub forward to 8, then stop
        m.stopIncluding(at: 8)

        assertSegments(m, expected: [
            (0, 2, false),
            (2, 8, true),
            (8, 10, false)
        ], keptDuration: 6.0)
    }

    // MARK: - Edge Cases

    /// TC-030: Rapid toggle on/off at same position
    ///
    /// Keep on and immediately off at 5s → zero-length, no-op.
    func testTC030_rapidToggleSamePosition() {
        let m = SegmentManager()

        m.beginIncluding(at: 5, videoDuration: videoDuration)
        m.stopIncluding(at: 5)

        assertSegments(m, expected: [
            (0, 10, false)
        ], keptDuration: 0.0)
    }

    /// TC-031: Keep at very start (0s)
    ///
    /// No excluded leader segment before the kept portion.
    func testTC031_keepAtVeryStart() {
        let m = SegmentManager()

        m.beginIncluding(at: 0, videoDuration: videoDuration)
        m.stopIncluding(at: 3)

        assertSegments(m, expected: [
            (0, 3, true),
            (3, 10, false)
        ], keptDuration: 3.0)
    }

    /// TC-032: Keep at very end, video finishes while keeping
    ///
    /// Keep starts at 8s, video ends → auto-finalize, last 2s kept.
    func testTC032_keepAtEndVideoFinishes() {
        let m = SegmentManager()

        m.beginIncluding(at: 8, videoDuration: videoDuration)
        // videoEnd → stopIncluding at video duration
        m.stopIncluding(at: 10)

        assertSegments(m, expected: [
            (0, 8, false),
            (8, 10, true)
        ], keptDuration: 2.0)
    }

    /// TC-033: Toggle segment via long-press, then re-keep over it
    ///
    /// Keep [3–7], long-press delete → empty. Then re-keep [2–5].
    func testTC033_toggleThenReKeep() {
        let m = SegmentManager()

        // Create [3–7]
        m.beginIncluding(at: 3, videoDuration: videoDuration)
        m.stopIncluding(at: 7)
        assertSegments(m, expected: [
            (0, 3, false),
            (3, 7, true),
            (7, 10, false)
        ], keptDuration: 4.0)

        // Long-press at 5 → toggle [3–7] to excluded
        let segAt5 = m.segment(at: 5)!
        m.toggleSegment(id: segAt5.id)
        assertSegments(m, expected: [
            (0, 10, false)
        ], keptDuration: 0.0)

        // Re-keep [2–5]
        m.beginIncluding(at: 2, videoDuration: videoDuration)
        m.stopIncluding(at: 5)
        assertSegments(m, expected: [
            (0, 2, false),
            (2, 5, true),
            (5, 10, false)
        ], keptDuration: 3.0)
    }

    /// TC-034: Nothing kept — export blocked
    ///
    /// No keep interactions → canExport is false.
    func testTC034_nothingKeptExportBlocked() {
        let m = SegmentManager()
        // No interactions — segments array is empty, nothing kept
        XCTAssertEqual(m.totalIncludedDuration, 0.0, accuracy: 0.01)
        XCTAssertFalse(m.totalIncludedDuration > 0, "canExport should be false")
    }

    /// TC-035: Entire video kept
    ///
    /// Keep from 0, video ends → entire 10s kept.
    func testTC035_entireVideoKept() {
        let m = SegmentManager()

        m.beginIncluding(at: 0, videoDuration: videoDuration)
        // videoEnd → stopIncluding at video duration
        m.stopIncluding(at: 10)

        assertSegments(m, expected: [
            (0, 10, true)
        ], keptDuration: 10.0)
    }

    // MARK: - Delete (Long-Press Toggle)

    /// TC-040: Keep a segment, long-press to delete it
    ///
    /// Keep [2–6], long-press at 4 → excluded, merges to one big excluded segment.
    func testTC040_keepThenLongPressDelete() {
        let m = SegmentManager()

        // Create [2–6]
        m.beginIncluding(at: 2, videoDuration: videoDuration)
        m.stopIncluding(at: 6)
        assertSegments(m, expected: [
            (0, 2, false),
            (2, 6, true),
            (6, 10, false)
        ], keptDuration: 4.0)

        // Long-press at 4 → toggle [2–6] to excluded
        let segAt4 = m.segment(at: 4)!
        m.toggleSegment(id: segAt4.id)
        assertSegments(m, expected: [
            (0, 10, false)
        ], keptDuration: 0.0)
    }

    /// TC-041: Delete segment, long-press gap to re-include
    ///
    /// Create [2–4] and [6–8], delete [6–8] via long-press,
    /// then long-press the gap to re-include → merges to [2–10] kept.
    func testTC041_deleteThenReIncludeViaLongPress() {
        let m = SegmentManager()

        // Create [2–4]
        m.beginIncluding(at: 2, videoDuration: videoDuration)
        m.stopIncluding(at: 4)
        assertSegments(m, expected: [
            (0, 2, false),
            (2, 4, true),
            (4, 10, false)
        ], keptDuration: 2.0)

        // Create [6–8]
        m.beginIncluding(at: 6, videoDuration: videoDuration)
        m.stopIncluding(at: 8)
        assertSegments(m, expected: [
            (0, 2, false),
            (2, 4, true),
            (4, 6, false),
            (6, 8, true),
            (8, 10, false)
        ], keptDuration: 4.0)

        // Long-press at 7 → delete [6–8]
        let segAt7 = m.segment(at: 7)!
        m.toggleSegment(id: segAt7.id)
        assertSegments(m, expected: [
            (0, 2, false),
            (2, 4, true),
            (4, 10, false)
        ], keptDuration: 2.0)

        // Long-press at 7 again → re-include [4–10], merges with [2–4]
        let segAt7After = m.segment(at: 7)!
        m.toggleSegment(id: segAt7After.id)
        assertSegments(m, expected: [
            (0, 2, false),
            (2, 10, true)
        ], keptDuration: 8.0)
    }

    /// TC-042: Delete one segment, keep over the gap
    ///
    /// Create [1–3] and [6–8], delete [1–3] via long-press,
    /// then keep [2–5] in the resulting gap. Second segment [6–8] untouched.
    func testTC042_deleteOneKeepOverGap() {
        let m = SegmentManager()

        // Create [1–3]
        m.beginIncluding(at: 1, videoDuration: videoDuration)
        m.stopIncluding(at: 3)
        assertSegments(m, expected: [
            (0, 1, false),
            (1, 3, true),
            (3, 10, false)
        ], keptDuration: 2.0)

        // Create [6–8]
        m.beginIncluding(at: 6, videoDuration: videoDuration)
        m.stopIncluding(at: 8)
        assertSegments(m, expected: [
            (0, 1, false),
            (1, 3, true),
            (3, 6, false),
            (6, 8, true),
            (8, 10, false)
        ], keptDuration: 4.0)

        // Long-press at 2 → delete [1–3]
        let segAt2 = m.segment(at: 2)!
        m.toggleSegment(id: segAt2.id)
        assertSegments(m, expected: [
            (0, 6, false),
            (6, 8, true),
            (8, 10, false)
        ], keptDuration: 2.0)

        // Keep [2–5] in the gap
        m.beginIncluding(at: 2, videoDuration: videoDuration)
        m.stopIncluding(at: 5)
        assertSegments(m, expected: [
            (0, 2, false),
            (2, 5, true),
            (5, 6, false),
            (6, 8, true),
            (8, 10, false)
        ], keptDuration: 5.0)
    }

    // MARK: - Additional Stress & Edge Case Tests (Code Review)

    /// Stress: Double beginIncluding without stopIncluding.
    ///
    /// If beginIncluding is called twice before stopIncluding, the second
    /// call overwrites the recording start. The final stop should still
    /// produce a valid segment from the *second* begin's context.
    func testStress_doubleBeginWithoutStop() {
        let m = SegmentManager()

        // First begin at 2
        m.beginIncluding(at: 2, videoDuration: videoDuration)
        // Second begin at 5 — overwrites snapshot and recordingStartTime
        m.beginIncluding(at: 5, videoDuration: videoDuration)
        // Stop at 7 — should use the second begin's context
        m.stopIncluding(at: 7)

        // The second beginIncluding(at: 5) captured the snapshot from after
        // the first beginIncluding modified segments. When we stop at 7,
        // stopIncluding restores to that snapshot and replaces the range.
        // The first begin created [{0-2, false}, {2-10, true}].
        // The second begin's snapshot is [{0-2, false}, {2-10, true}].
        // stopIncluding restores that, finds {2-10, true} overlapping [5,7],
        // extends effectiveStart to 2, excludes [2-10], then includes [2-7].
        assertSegments(m, expected: [
            (0, 2, false),
            (2, 7, true),
            (7, 10, false)
        ], keptDuration: 5.0)
    }

    /// Stress: stopIncluding without any prior beginIncluding.
    ///
    /// Falls back to point-in-time split. On an empty manager, this is a no-op.
    func testStress_stopWithoutBegin_emptyManager() {
        let m = SegmentManager()

        m.stopIncluding(at: 5)

        // Empty manager → no-op
        XCTAssertEqual(m.segments.count, 0)
        XCTAssertEqual(m.totalIncludedDuration, 0.0)
    }

    /// Stress: stopIncluding without beginIncluding on existing segments.
    ///
    /// Fallback path: splits the included segment at the given time.
    func testStress_stopWithoutBegin_existingSegments() {
        let m = SegmentManager()

        // Set up segments manually via begin/stop
        m.beginIncluding(at: 2, videoDuration: videoDuration)
        m.stopIncluding(at: 8)
        assertSegments(m, expected: [
            (0, 2, false),
            (2, 8, true),
            (8, 10, false)
        ], keptDuration: 6.0)

        // Now call stopIncluding without beginIncluding — fallback split
        m.stopIncluding(at: 5)
        assertSegments(m, expected: [
            (0, 2, false),
            (2, 5, true),
            (5, 10, false)
        ], keptDuration: 3.0)
    }

    /// Stress: Very small segment (0.001 seconds).
    ///
    /// Should survive cleanup as a valid segment.
    func testStress_verySmallSegment() {
        let m = SegmentManager()

        m.beginIncluding(at: 5.0, videoDuration: videoDuration)
        m.stopIncluding(at: 5.001)

        // 0.001s is > 0, so isValid is true and the segment should exist
        XCTAssertEqual(m.segments.count, 3)
        let keptSeg = m.segments.first(where: \.isIncluded)
        XCTAssertNotNil(keptSeg)
        XCTAssertEqual(keptSeg!.startTime, 5.0, accuracy: 0.001)
        XCTAssertEqual(keptSeg!.endTime, 5.001, accuracy: 0.001)
        XCTAssertEqual(m.totalIncludedDuration, 0.001, accuracy: 0.001)
    }

    /// Stress: Many small segments, then re-keep over all of them.
    ///
    /// Creates 5 tiny kept segments, then one big re-keep swallows them all.
    func testStress_manySmallSegmentsThenReKeepAll() {
        let m = SegmentManager()

        // Create 5 small 0.5s kept segments: [1-1.5], [3-3.5], [5-5.5], [7-7.5], [9-9.5]
        let starts: [Double] = [1, 3, 5, 7, 9]
        for s in starts {
            m.beginIncluding(at: s, videoDuration: videoDuration)
            m.stopIncluding(at: s + 0.5)
        }

        // Should have 11 segments total (5 kept + 6 excluded gaps)
        XCTAssertEqual(m.segments.count, 11,
                       "Segments: \(m.segments.map { "[\(String(format: "%.1f", $0.startTime))-\(String(format: "%.1f", $0.endTime)) \($0.isIncluded ? "kept" : "cut")]" })")
        XCTAssertEqual(m.totalIncludedDuration, 2.5, accuracy: 0.01)

        // Now re-keep from 0 to 10 — swallow everything
        m.beginIncluding(at: 0, videoDuration: videoDuration)
        m.stopIncluding(at: 10)

        assertSegments(m, expected: [
            (0, 10, true)
        ], keptDuration: 10.0)
    }

    /// Stress: Rapid toggling — on/off/on/off at incrementing positions.
    ///
    /// Simulates a user rapidly tapping keep as video plays: keep [1-2], [3-4], [5-6].
    func testStress_rapidTogglingSequence() {
        let m = SegmentManager()

        // Three rapid keep cycles
        m.beginIncluding(at: 1, videoDuration: videoDuration)
        m.stopIncluding(at: 2)
        m.beginIncluding(at: 3, videoDuration: videoDuration)
        m.stopIncluding(at: 4)
        m.beginIncluding(at: 5, videoDuration: videoDuration)
        m.stopIncluding(at: 6)

        assertSegments(m, expected: [
            (0, 1, false),
            (1, 2, true),
            (2, 3, false),
            (3, 4, true),
            (4, 5, false),
            (5, 6, true),
            (6, 10, false)
        ], keptDuration: 3.0)
    }

    /// Edge: beginIncluding exactly at videoDuration.
    ///
    /// Starting a keep at the very end of the video should create
    /// a zero-duration included segment which gets cleaned up.
    func testEdge_beginIncludingAtVideoDuration() {
        let m = SegmentManager()

        m.beginIncluding(at: 10, videoDuration: videoDuration)

        // The included segment [10-10] is zero-duration → removed by cleanup
        // Only the excluded leader [0-10] should remain
        assertSegments(m, expected: [
            (0, 10, false)
        ], keptDuration: 0.0)
    }

    /// Edge: beginIncluding with videoDuration = 0.
    ///
    /// Guard clause should prevent any segment creation.
    func testEdge_zeroDurationVideo() {
        let m = SegmentManager()

        m.beginIncluding(at: 0, videoDuration: 0)

        XCTAssertEqual(m.segments.count, 0)
    }

    /// Edge: Keep at exactly 0, stop at exactly videoDuration.
    ///
    /// Full coverage — no excluded segments, just one big included.
    func testEdge_exactBoundaries_fullRange() {
        let m = SegmentManager()

        m.beginIncluding(at: 0.0, videoDuration: videoDuration)
        m.stopIncluding(at: 10.0)

        assertSegments(m, expected: [
            (0, 10, true)
        ], keptDuration: 10.0)
    }

    /// Stress: Reset and re-use.
    ///
    /// After reset(), the manager should behave as if freshly created.
    func testStress_resetAndReuse() {
        let m = SegmentManager()

        // Create some segments
        m.beginIncluding(at: 2, videoDuration: videoDuration)
        m.stopIncluding(at: 8)
        XCTAssertEqual(m.segments.count, 3)

        // Reset
        m.reset()
        XCTAssertEqual(m.segments.count, 0)
        XCTAssertEqual(m.totalIncludedDuration, 0.0)

        // Re-use — should work clean
        m.beginIncluding(at: 1, videoDuration: videoDuration)
        m.stopIncluding(at: 5)
        assertSegments(m, expected: [
            (0, 1, false),
            (1, 5, true),
            (5, 10, false)
        ], keptDuration: 4.0)
    }

    /// Stress: replaceSegments (persistence restore path).
    ///
    /// Restoring segments should sort them and clear recording state.
    func testStress_replaceSegments() {
        let m = SegmentManager()

        // Start a recording (sets internal state)
        m.beginIncluding(at: 3, videoDuration: videoDuration)

        // Replace with a manually-constructed segment set (reverse order to test sorting)
        let restored = [
            Segment(startTime: 5, endTime: 10, isIncluded: false),
            Segment(startTime: 0, endTime: 5, isIncluded: true),
        ]
        m.replaceSegments(restored)

        // Should be sorted and recording state cleared
        assertSegments(m, expected: [
            (0, 5, true),
            (5, 10, false)
        ], keptDuration: 5.0)

        // A new begin/stop should work fresh (no stale recording state)
        m.beginIncluding(at: 7, videoDuration: videoDuration)
        m.stopIncluding(at: 9)
        assertSegments(m, expected: [
            (0, 5, true),
            (5, 7, false),
            (7, 9, true),
            (9, 10, false)
        ], keptDuration: 7.0)
    }

    /// Stress: finalizeSegments caps segments beyond video duration.
    func testStress_finalizeSegments() {
        let m = SegmentManager()

        // Create a segment that extends to 10 (videoDuration)
        m.beginIncluding(at: 3, videoDuration: 10)
        // The open segment goes to videoDuration=10

        // Finalize with a SHORTER actual duration (simulates duration correction)
        m.finalizeSegments(videoDuration: 8)

        // Segment at index 0: [0-3, false] → endTime 3 <= 8, unchanged
        // Segment at index 1: [3-10, true] → endTime 10 > 8, capped to 8
        XCTAssertTrue(m.segments.allSatisfy { $0.endTime <= 8 })
        XCTAssertEqual(m.segments.last?.endTime ?? 0, 8.0, accuracy: 0.01)
    }

    /// Stress: Adjacent kept segments that should merge after toggle.
    ///
    /// Create [2-4] and [4-6] as separate keeps. Since they're adjacent and
    /// both kept, they should merge into [2-6].
    func testStress_adjacentKeptSegmentsMerge() {
        let m = SegmentManager()

        // First keep [2-4]
        m.beginIncluding(at: 2, videoDuration: videoDuration)
        m.stopIncluding(at: 4)

        // Second keep [4-6] — starts exactly where the first ends
        m.beginIncluding(at: 4, videoDuration: videoDuration)
        m.stopIncluding(at: 6)

        // The two adjacent kept segments should merge into one [2-6]
        assertSegments(m, expected: [
            (0, 2, false),
            (2, 6, true),
            (6, 10, false)
        ], keptDuration: 4.0)
    }

    /// Edge: segment(at:) lookup at exact boundaries.
    ///
    /// BUG FOUND: `segment(at:)` returns nil when time == last segment's endTime.
    /// The private `segmentIndex(containing:)` has a fallback for this, but the
    /// public `segment(at:)` does not. Internal operations (beginIncluding, etc.)
    /// work correctly, but external callers (UI) may get nil at the video end.
    func testEdge_segmentLookupAtBoundaries() {
        let m = SegmentManager()

        m.beginIncluding(at: 3, videoDuration: videoDuration)
        m.stopIncluding(at: 7)

        // At t=0 → should be in the excluded [0-3] segment
        let seg0 = m.segment(at: 0)
        XCTAssertNotNil(seg0)
        XCTAssertFalse(seg0!.isIncluded)

        // At t=3 → should be in the included [3-7] segment (start inclusive)
        let seg3 = m.segment(at: 3)
        XCTAssertNotNil(seg3)
        XCTAssertTrue(seg3!.isIncluded)

        // At t=7 → should be in the excluded [7-10] segment (end exclusive on [3-7])
        let seg7 = m.segment(at: 7)
        XCTAssertNotNil(seg7)
        XCTAssertFalse(seg7!.isIncluded)

        // At t=10 → BUG: segment(at:) returns nil because contains() uses [start, end)
        // and the private segmentIndex(containing:) fallback is not used here.
        // This should ideally return the last segment, but currently returns nil.
        let seg10 = m.segment(at: 10)
        XCTAssertNil(seg10, "Known limitation: segment(at:) returns nil at exact endTime of last segment")
    }

    /// Stress: splitSegment — split a segment at a point, both halves keep state.
    func testStress_splitSegment() {
        let m = SegmentManager()

        m.beginIncluding(at: 2, videoDuration: videoDuration)
        m.stopIncluding(at: 8)

        // Split the included [2-8] at 5
        m.splitSegment(at: 5)

        // Should now be 4 segments: [0-2 false], [2-5 true], [5-8 true], [8-10 false]
        XCTAssertEqual(m.segments.count, 4)
        XCTAssertEqual(m.segments[1].startTime, 2.0, accuracy: 0.01)
        XCTAssertEqual(m.segments[1].endTime, 5.0, accuracy: 0.01)
        XCTAssertTrue(m.segments[1].isIncluded)
        XCTAssertEqual(m.segments[2].startTime, 5.0, accuracy: 0.01)
        XCTAssertEqual(m.segments[2].endTime, 8.0, accuracy: 0.01)
        XCTAssertTrue(m.segments[2].isIncluded)

        // Total kept duration unchanged
        XCTAssertEqual(m.totalIncludedDuration, 6.0, accuracy: 0.01)
    }

    /// Stress: splitSegment at boundary — should be a no-op.
    func testStress_splitSegmentAtBoundary() {
        let m = SegmentManager()

        m.beginIncluding(at: 2, videoDuration: videoDuration)
        m.stopIncluding(at: 8)

        let countBefore = m.segments.count

        // Split at exact start of segment — no-op
        m.splitSegment(at: 2)
        XCTAssertEqual(m.segments.count, countBefore)

        // Split at exact end of segment — no-op
        m.splitSegment(at: 8)
        XCTAssertEqual(m.segments.count, countBefore)
    }

    /// Stress: Negative time should be clamped to 0.
    func testEdge_negativeTimeClamped() {
        let m = SegmentManager()

        m.beginIncluding(at: -5, videoDuration: videoDuration)
        m.stopIncluding(at: 3)

        // -5 clamped to 0
        assertSegments(m, expected: [
            (0, 3, true),
            (3, 10, false)
        ], keptDuration: 3.0)
    }

    /// Integration: Full workflow — create, delete, re-keep, toggle, finalize.
    ///
    /// Simulates a real editing session from start to finish.
    func testIntegration_fullEditingWorkflow() {
        let m = SegmentManager()

        // 1. First pass: keep [2-6]
        m.beginIncluding(at: 2, videoDuration: videoDuration)
        m.stopIncluding(at: 6)
        assertSegments(m, expected: [
            (0, 2, false), (2, 6, true), (6, 10, false)
        ], keptDuration: 4.0)

        // 2. Second pass: keep [8-9]
        m.beginIncluding(at: 8, videoDuration: videoDuration)
        m.stopIncluding(at: 9)
        assertSegments(m, expected: [
            (0, 2, false), (2, 6, true), (6, 8, false), (8, 9, true), (9, 10, false)
        ], keptDuration: 5.0)

        // 3. Delete [2-6] via toggle
        let seg = m.segment(at: 4)!
        m.toggleSegment(id: seg.id)
        assertSegments(m, expected: [
            (0, 8, false), (8, 9, true), (9, 10, false)
        ], keptDuration: 1.0)

        // 4. Re-keep [1-5] in the now-empty region
        m.beginIncluding(at: 1, videoDuration: videoDuration)
        m.stopIncluding(at: 5)
        assertSegments(m, expected: [
            (0, 1, false), (1, 5, true), (5, 8, false), (8, 9, true), (9, 10, false)
        ], keptDuration: 5.0)

        // 5. Re-keep over everything [0-10]
        m.beginIncluding(at: 0, videoDuration: videoDuration)
        m.stopIncluding(at: 10)
        assertSegments(m, expected: [
            (0, 10, true)
        ], keptDuration: 10.0)

        // 6. Finalize
        let finalized = m.finalizeSegments(videoDuration: videoDuration)
        XCTAssertEqual(finalized.count, 1)
        XCTAssertEqual(finalized[0].startTime, 0.0, accuracy: 0.01)
        XCTAssertEqual(finalized[0].endTime, 10.0, accuracy: 0.01)
        XCTAssertTrue(finalized[0].isIncluded)
    }
}
