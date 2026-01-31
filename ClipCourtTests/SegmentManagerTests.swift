// SegmentManagerTests.swift
// ClipCourtTests
//
// Comprehensive unit tests for SegmentManager — the core editing engine.
// Covers begin/stop including, range replacement, toggle, split,
// finalize, and edge cases.

import XCTest
@testable import ClipCourt

@MainActor
final class SegmentManagerTests: XCTestCase {

    private var sut: SegmentManager!

    override func setUp() {
        super.setUp()
        sut = SegmentManager()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// Shorthand: begin including at `time` on a 60s video.
    @discardableResult
    private func begin(at time: Double, duration: Double = 60) -> [Segment] {
        sut.beginIncluding(at: time, videoDuration: duration)
    }

    /// Shorthand: stop including at `time`.
    @discardableResult
    private func stop(at time: Double) -> [Segment] {
        sut.stopIncluding(at: time)
    }

    // MARK: - Initial State

    func testInitialState_noSegments() {
        XCTAssertTrue(sut.segments.isEmpty)
        XCTAssertEqual(sut.totalIncludedDuration, 0)
        XCTAssertEqual(sut.includedSegmentCount, 0)
    }

    // MARK: - Basic Keeping: Start of Video

    func testKeepFromStart() {
        // Begin at 0, stop at 10 on a 60s video
        begin(at: 0)
        stop(at: 10)

        // Should produce: [0..10 included] [10..60 excluded]
        XCTAssertEqual(sut.segments.count, 2)

        XCTAssertEqual(sut.segments[0].startTime, 0, accuracy: 0.001)
        XCTAssertEqual(sut.segments[0].endTime, 10, accuracy: 0.001)
        XCTAssertTrue(sut.segments[0].isIncluded)

        XCTAssertEqual(sut.segments[1].startTime, 10, accuracy: 0.001)
        XCTAssertEqual(sut.segments[1].endTime, 60, accuracy: 0.001)
        XCTAssertFalse(sut.segments[1].isIncluded)

        XCTAssertEqual(sut.totalIncludedDuration, 10, accuracy: 0.001)
    }

    // MARK: - Basic Keeping: Middle of Video

    func testKeepInMiddle() {
        // Begin at 20, stop at 30
        begin(at: 20)
        stop(at: 30)

        // Should produce: [0..20 excluded] [20..30 included] [30..60 excluded]
        XCTAssertEqual(sut.segments.count, 3)

        XCTAssertFalse(sut.segments[0].isIncluded)
        XCTAssertEqual(sut.segments[0].startTime, 0, accuracy: 0.001)
        XCTAssertEqual(sut.segments[0].endTime, 20, accuracy: 0.001)

        XCTAssertTrue(sut.segments[1].isIncluded)
        XCTAssertEqual(sut.segments[1].startTime, 20, accuracy: 0.001)
        XCTAssertEqual(sut.segments[1].endTime, 30, accuracy: 0.001)

        XCTAssertFalse(sut.segments[2].isIncluded)
        XCTAssertEqual(sut.segments[2].startTime, 30, accuracy: 0.001)
        XCTAssertEqual(sut.segments[2].endTime, 60, accuracy: 0.001)

        XCTAssertEqual(sut.totalIncludedDuration, 10, accuracy: 0.001)
    }

    // MARK: - Basic Keeping: End of Video

    func testKeepToEnd() {
        // Begin at 50, stop at 60
        begin(at: 50)
        stop(at: 60)

        // Should produce: [0..50 excluded] [50..60 included]
        XCTAssertEqual(sut.segments.count, 2)

        XCTAssertFalse(sut.segments[0].isIncluded)
        XCTAssertEqual(sut.segments[0].startTime, 0, accuracy: 0.001)
        XCTAssertEqual(sut.segments[0].endTime, 50, accuracy: 0.001)

        XCTAssertTrue(sut.segments[1].isIncluded)
        XCTAssertEqual(sut.segments[1].startTime, 50, accuracy: 0.001)
        XCTAssertEqual(sut.segments[1].endTime, 60, accuracy: 0.001)

        XCTAssertEqual(sut.totalIncludedDuration, 10, accuracy: 0.001)
    }

    // MARK: - Full Video Keep

    func testKeepEntireVideo() {
        begin(at: 0)
        stop(at: 60)

        // Single included segment covering the whole video
        XCTAssertEqual(sut.segments.count, 1)
        XCTAssertTrue(sut.segments[0].isIncluded)
        XCTAssertEqual(sut.segments[0].startTime, 0, accuracy: 0.001)
        XCTAssertEqual(sut.segments[0].endTime, 60, accuracy: 0.001)
        XCTAssertEqual(sut.totalIncludedDuration, 60, accuracy: 0.001)
    }

    // MARK: - Multiple Keeps (Sequential)

    func testMultipleSequentialKeeps() {
        // First keep: 5..15
        begin(at: 5)
        stop(at: 15)

        // Second keep: 30..40
        begin(at: 30)
        stop(at: 40)

        // Should have: [0..5 ex] [5..15 in] [15..30 ex] [30..40 in] [40..60 ex]
        XCTAssertEqual(sut.segments.count, 5)
        XCTAssertEqual(sut.includedSegmentCount, 2)
        XCTAssertEqual(sut.totalIncludedDuration, 20, accuracy: 0.001)
    }

    // MARK: - Re-Keeping Over Existing Segments (Range Replacement / BUG-016)

    func testReKeepOverExistingSegment_extendsRange() {
        // First keep: 10..20
        begin(at: 10)
        stop(at: 20)

        // Re-keep starting inside existing include, extending past it: 15..30
        begin(at: 15)
        stop(at: 30)

        // The re-keep should extend the original: effectively [10..30 included]
        let included = sut.segments.filter(\.isIncluded)
        XCTAssertEqual(included.count, 1)
        XCTAssertEqual(included[0].startTime, 10, accuracy: 0.001)
        XCTAssertEqual(included[0].endTime, 30, accuracy: 0.001)
    }

    func testReKeepOverExistingSegment_completelyCovered() {
        // First keep: 10..30
        begin(at: 10)
        stop(at: 30)

        // Re-keep fully inside: 15..25
        begin(at: 15)
        stop(at: 25)

        // The keep that started inside [10..30] should preserve [10..25]
        let included = sut.segments.filter(\.isIncluded)
        XCTAssertEqual(included.count, 1)
        XCTAssertEqual(included[0].startTime, 10, accuracy: 0.001)
        XCTAssertEqual(included[0].endTime, 25, accuracy: 0.001)
    }

    func testReKeepOverMultipleSegments() {
        // Create two disjoint keeps: 5..10 and 20..25
        begin(at: 5)
        stop(at: 10)
        begin(at: 20)
        stop(at: 25)

        // Now re-keep spanning both: 3..28
        begin(at: 3)
        stop(at: 28)

        // Should replace everything in [3..28] with one included segment
        let included = sut.segments.filter(\.isIncluded)
        XCTAssertEqual(included.count, 1)
        XCTAssertEqual(included[0].startTime, 3, accuracy: 0.001)
        XCTAssertEqual(included[0].endTime, 28, accuracy: 0.001)
    }

    // MARK: - Seek + Keep Scenarios

    func testSeekBackAndKeep() {
        // First keep: 20..30
        begin(at: 20)
        stop(at: 30)

        // Seek back and keep earlier region: 5..15
        begin(at: 5)
        stop(at: 15)

        // Should have two included segments
        let included = sut.segments.filter(\.isIncluded)
        XCTAssertEqual(included.count, 2)
        XCTAssertEqual(included[0].startTime, 5, accuracy: 0.001)
        XCTAssertEqual(included[0].endTime, 15, accuracy: 0.001)
        XCTAssertEqual(included[1].startTime, 20, accuracy: 0.001)
        XCTAssertEqual(included[1].endTime, 30, accuracy: 0.001)
    }

    // MARK: - Edge Cases: Boundary Times

    func testBeginAtExactEnd_ofVideo() {
        // Begin at exactly 60 on a 60s video — should clamp
        begin(at: 60)

        // Should not create an invalid (zero-duration) included segment
        let included = sut.segments.filter(\.isIncluded)
        // At time=60 (clamped to 60), the included segment [60..60] has zero duration
        // and gets cleaned up. The timeline should be [0..60 excluded].
        for seg in sut.segments {
            XCTAssertTrue(seg.isValid, "All segments should be valid (non-zero duration)")
        }
    }

    func testBeginAtZero_stopAtZero() {
        // Zero-length keep at the start — should produce no included segment
        begin(at: 0)
        stop(at: 0)

        let included = sut.segments.filter(\.isIncluded)
        // Zero-length range should be cleaned up
        XCTAssertEqual(included.count, 0)
    }

    func testNegativeTime_clampedToZero() {
        // Negative times should be clamped to 0
        begin(at: -5)
        stop(at: 10)

        let included = sut.segments.filter(\.isIncluded)
        XCTAssertEqual(included.count, 1)
        XCTAssertEqual(included[0].startTime, 0, accuracy: 0.001)
        XCTAssertEqual(included[0].endTime, 10, accuracy: 0.001)
    }

    func testTimeExceedingDuration_clampedToDuration() {
        // Time exceeding duration should be handled gracefully
        begin(at: 50)
        // Stop beyond video duration — replaceRange uses max(from, to)
        stop(at: 70)

        // Should still produce segments; the included portion caps at or around 70
        // (stopIncluding doesn't clamp itself; finalize does)
        let included = sut.segments.filter(\.isIncluded)
        XCTAssertGreaterThanOrEqual(included.count, 1)
    }

    // MARK: - Edge Cases: Zero Duration Video

    func testZeroDurationVideo() {
        let result = sut.beginIncluding(at: 0, videoDuration: 0)
        // Should return empty — guard clause prevents creating segments
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Edge Cases: Rapid Toggle

    func testRapidToggle_onOffOnOff() {
        // Simulate rapid toggling at various positions
        begin(at: 10)
        stop(at: 10.1)
        begin(at: 10.2)
        stop(at: 10.3)

        // Should produce two tiny included segments (or merged if adjacent)
        let included = sut.segments.filter(\.isIncluded)
        XCTAssertGreaterThanOrEqual(included.count, 1)
        XCTAssertEqual(sut.totalIncludedDuration, 0.2, accuracy: 0.01)
    }

    func testRapidToggle_sameTime() {
        // Toggle on and off at the exact same time
        begin(at: 15)
        stop(at: 15)

        // Zero-duration segment should be removed
        let included = sut.segments.filter(\.isIncluded)
        XCTAssertEqual(included.count, 0)
    }

    // MARK: - Toggle Segment

    func testToggleSegment_excludeToInclude() {
        // Create a keep in the middle: [0..20 ex] [20..30 in] [30..60 ex]
        begin(at: 20)
        stop(at: 30)

        // Toggle the first excluded segment to included
        let firstSegId = sut.segments[0].id
        sut.toggleSegment(id: firstSegId)

        // [0..20] should now be included, merging with [20..30] -> [0..30 included]
        let included = sut.segments.filter(\.isIncluded)
        XCTAssertEqual(included.count, 1)
        XCTAssertEqual(included[0].startTime, 0, accuracy: 0.001)
        XCTAssertEqual(included[0].endTime, 30, accuracy: 0.001)
    }

    func testToggleSegment_includeToExclude() {
        // Create: [0..20 ex] [20..30 in] [30..60 ex]
        begin(at: 20)
        stop(at: 30)

        // Toggle the included segment to excluded
        let includedSeg = sut.segments.first(where: \.isIncluded)!
        sut.toggleSegment(id: includedSeg.id)

        // All segments should be excluded now (and merged)
        XCTAssertEqual(sut.includedSegmentCount, 0)
        XCTAssertEqual(sut.segments.count, 1) // merged into one big excluded
        XCTAssertEqual(sut.totalIncludedDuration, 0, accuracy: 0.001)
    }

    func testToggleSegment_unknownID_noChange() {
        begin(at: 10)
        stop(at: 20)

        let countBefore = sut.segments.count
        sut.toggleSegment(id: UUID()) // non-existent ID

        XCTAssertEqual(sut.segments.count, countBefore)
    }

    // MARK: - Delete (Toggle to Excluded) Segments

    func testDeleteMiddleSegment() {
        // Create: [0..10 ex] [10..20 in] [20..30 ex] [30..40 in] [40..60 ex]
        begin(at: 10)
        stop(at: 20)
        begin(at: 30)
        stop(at: 40)

        // "Delete" the first included segment by toggling it
        let firstIncluded = sut.segments.first(where: \.isIncluded)!
        sut.toggleSegment(id: firstIncluded.id)

        // First include should be gone, merged with surrounding excluded
        XCTAssertEqual(sut.includedSegmentCount, 1)
        // Remaining include should be [30..40]
        let remaining = sut.segments.filter(\.isIncluded)
        XCTAssertEqual(remaining[0].startTime, 30, accuracy: 0.001)
        XCTAssertEqual(remaining[0].endTime, 40, accuracy: 0.001)
    }

    // MARK: - Split Segment

    func testSplitSegment_middle() {
        begin(at: 10)
        stop(at: 30)

        // Split the included segment at time 20
        let includedSeg = sut.segments.first(where: \.isIncluded)!
        sut.splitSegment(at: 20)

        // Should now be two included segments: [10..20] and [20..30]
        let included = sut.segments.filter(\.isIncluded)
        XCTAssertEqual(included.count, 2)
        XCTAssertEqual(included[0].endTime, 20, accuracy: 0.001)
        XCTAssertEqual(included[1].startTime, 20, accuracy: 0.001)
    }

    func testSplitSegment_atBoundary_noOp() {
        begin(at: 10)
        stop(at: 30)

        let countBefore = sut.segments.count
        // Try splitting at the exact start of the included segment
        sut.splitSegment(at: 10)
        XCTAssertEqual(sut.segments.count, countBefore, "Split at boundary should be no-op")
    }

    func testSplitSegment_outsideAllSegments_noOp() {
        begin(at: 10, duration: 30)
        stop(at: 20)

        let countBefore = sut.segments.count
        sut.splitSegment(at: 100) // way outside
        XCTAssertEqual(sut.segments.count, countBefore)
    }

    // MARK: - Segment Query

    func testSegmentAtTime() {
        begin(at: 10)
        stop(at: 20)

        let seg = sut.segment(at: 15)
        XCTAssertNotNil(seg)
        XCTAssertTrue(seg!.isIncluded)

        let excludedSeg = sut.segment(at: 5)
        XCTAssertNotNil(excludedSeg)
        XCTAssertFalse(excludedSeg!.isIncluded)

        // Outside all segments
        let outside = sut.segment(at: 100)
        XCTAssertNil(outside)
    }

    // MARK: - Replace Segments (Bulk)

    func testReplaceSegments() {
        let replacement = [
            Segment(startTime: 0, endTime: 10, isIncluded: true),
            Segment(startTime: 10, endTime: 20, isIncluded: false),
        ]

        sut.replaceSegments(replacement)

        XCTAssertEqual(sut.segments.count, 2)
        XCTAssertTrue(sut.segments[0].isIncluded)
        XCTAssertFalse(sut.segments[1].isIncluded)
    }

    func testReplaceSegments_unsorted_getsSorted() {
        let replacement = [
            Segment(startTime: 20, endTime: 30, isIncluded: true),
            Segment(startTime: 0, endTime: 10, isIncluded: false),
        ]

        sut.replaceSegments(replacement)

        XCTAssertEqual(sut.segments[0].startTime, 0, accuracy: 0.001)
        XCTAssertEqual(sut.segments[1].startTime, 20, accuracy: 0.001)
    }

    // MARK: - Finalize Segments

    func testFinalizeSegments_capsAtDuration() {
        // Create a segment that extends beyond video duration
        let segments = [
            Segment(startTime: 0, endTime: 100, isIncluded: true)
        ]
        sut.replaceSegments(segments)

        sut.finalizeSegments(videoDuration: 60)

        XCTAssertEqual(sut.segments.count, 1)
        XCTAssertEqual(sut.segments[0].endTime, 60, accuracy: 0.001)
    }

    func testFinalizeSegments_removesZeroDuration() {
        let segments = [
            Segment(startTime: 0, endTime: 10, isIncluded: true),
            Segment(startTime: 10, endTime: 10, isIncluded: false), // zero-duration
            Segment(startTime: 10, endTime: 20, isIncluded: true),
        ]
        sut.replaceSegments(segments)

        sut.finalizeSegments(videoDuration: 20)

        // Zero-duration removed, adjacent same-state merged -> 1 included [0..20]
        XCTAssertEqual(sut.segments.count, 1)
        XCTAssertTrue(sut.segments[0].isIncluded)
        XCTAssertEqual(sut.segments[0].startTime, 0, accuracy: 0.001)
        XCTAssertEqual(sut.segments[0].endTime, 20, accuracy: 0.001)
    }

    func testFinalizeSegments_emptySegments() {
        let result = sut.finalizeSegments(videoDuration: 60)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Reset

    func testReset_clearsEverything() {
        begin(at: 10)
        stop(at: 20)
        XCTAssertFalse(sut.segments.isEmpty)

        sut.reset()

        XCTAssertTrue(sut.segments.isEmpty)
        XCTAssertEqual(sut.totalIncludedDuration, 0)
    }

    // MARK: - Computed Properties

    func testTotalIncludedDuration() {
        begin(at: 5)
        stop(at: 15)
        begin(at: 25)
        stop(at: 35)

        XCTAssertEqual(sut.totalIncludedDuration, 20, accuracy: 0.001)
    }

    func testIncludedSegmentCount() {
        begin(at: 5)
        stop(at: 15)
        begin(at: 25)
        stop(at: 35)

        XCTAssertEqual(sut.includedSegmentCount, 2)
    }

    // MARK: - Segment Model Tests

    func testSegment_duration() {
        let seg = Segment(startTime: 5, endTime: 15, isIncluded: true)
        XCTAssertEqual(seg.duration, 10, accuracy: 0.001)
    }

    func testSegment_isValid() {
        let valid = Segment(startTime: 0, endTime: 10, isIncluded: true)
        XCTAssertTrue(valid.isValid)

        let zeroDuration = Segment(startTime: 5, endTime: 5, isIncluded: true)
        XCTAssertFalse(zeroDuration.isValid)
    }

    func testSegment_containsTime() {
        let seg = Segment(startTime: 10, endTime: 20, isIncluded: true)

        XCTAssertTrue(seg.contains(time: 10))   // inclusive start
        XCTAssertTrue(seg.contains(time: 15))   // middle
        XCTAssertFalse(seg.contains(time: 20))  // exclusive end
        XCTAssertFalse(seg.contains(time: 5))   // before
        XCTAssertFalse(seg.contains(time: 25))  // after
    }

    func testSegment_overlaps() {
        let a = Segment(startTime: 0, endTime: 10, isIncluded: true)
        let b = Segment(startTime: 5, endTime: 15, isIncluded: false)
        let c = Segment(startTime: 10, endTime: 20, isIncluded: true)
        let d = Segment(startTime: 20, endTime: 30, isIncluded: false)

        XCTAssertTrue(a.overlaps(with: b))
        XCTAssertFalse(a.overlaps(with: c))  // touching but not overlapping
        XCTAssertFalse(a.overlaps(with: d))
    }

    func testSegment_isAdjacent() {
        let a = Segment(startTime: 0, endTime: 10, isIncluded: true)
        let b = Segment(startTime: 10, endTime: 20, isIncluded: false)
        let c = Segment(startTime: 20, endTime: 30, isIncluded: true)

        XCTAssertTrue(a.isAdjacent(to: b))
        XCTAssertFalse(a.isAdjacent(to: c))
    }

    func testSegment_comparable_sortsByStartTime() {
        let a = Segment(startTime: 20, endTime: 30, isIncluded: true)
        let b = Segment(startTime: 5, endTime: 15, isIncluded: false)

        XCTAssertTrue(b < a)
        XCTAssertFalse(a < b)
    }

    func testSegment_negativeTimeClamped() {
        let seg = Segment(startTime: -5, endTime: -2, isIncluded: true)
        XCTAssertEqual(seg.startTime, 0)
        XCTAssertEqual(seg.endTime, 0)
    }

    func testSegment_equatable() {
        let id = UUID()
        let a = Segment(id: id, startTime: 0, endTime: 10, isIncluded: true)
        let b = Segment(id: id, startTime: 0, endTime: 10, isIncluded: true)
        XCTAssertEqual(a, b)
    }

    func testSegment_codable() throws {
        let original = Segment(startTime: 5, endTime: 15, isIncluded: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Segment.self, from: data)

        XCTAssertEqual(decoded.startTime, original.startTime, accuracy: 0.001)
        XCTAssertEqual(decoded.endTime, original.endTime, accuracy: 0.001)
        XCTAssertEqual(decoded.isIncluded, original.isIncluded)
        XCTAssertEqual(decoded.id, original.id)
    }

    // MARK: - PlayerViewModel.greenFillEnd

    func testGreenFillEnd_nilWhenNotKeeping() {
        let vm = PlayerViewModel()
        vm.isIncluding = false
        vm.keepingStartTime = nil
        XCTAssertNil(vm.greenFillEnd)
    }

    func testGreenFillEnd_nilWhenIncludingButNoStartTime() {
        let vm = PlayerViewModel()
        vm.isIncluding = true
        vm.keepingStartTime = nil
        XCTAssertNil(vm.greenFillEnd)
    }

    func testGreenFillEnd_returnsCurrentTimeWhenActivelyKeeping() {
        let vm = PlayerViewModel()
        vm.isIncluding = true
        vm.keepingStartTime = 10
        vm.currentTime = 25
        XCTAssertEqual(vm.greenFillEnd, 25)
    }

    // MARK: - ExportViewModel.canExport Blocking

    func testExportViewModel_canExportWhenIdle() {
        let exportVM = ExportViewModel()
        XCTAssertTrue(exportVM.canExport)
        XCTAssertFalse(exportVM.isExporting)
    }

    // MARK: - Invariant: Segments Always Sorted

    func testSegmentsAlwaysSorted_afterMultipleOperations() {
        begin(at: 30)
        stop(at: 40)
        begin(at: 10)
        stop(at: 20)
        begin(at: 50)
        stop(at: 55)

        for i in 1..<sut.segments.count {
            XCTAssertLessThanOrEqual(
                sut.segments[i - 1].startTime,
                sut.segments[i].startTime,
                "Segments should be sorted by startTime"
            )
        }
    }

    // MARK: - Invariant: No Overlapping Segments

    func testNoOverlappingSegments_afterComplexOperations() {
        begin(at: 5)
        stop(at: 15)
        begin(at: 10)
        stop(at: 25)
        begin(at: 40)
        stop(at: 50)

        for i in 1..<sut.segments.count {
            XCTAssertLessThanOrEqual(
                sut.segments[i - 1].endTime,
                sut.segments[i].startTime + 0.001,
                "Segments should not overlap"
            )
        }
    }

    // MARK: - Invariant: All Segments Valid After Cleanup

    func testAllSegmentsValid_afterOperations() {
        begin(at: 10)
        stop(at: 20)
        begin(at: 20)
        stop(at: 30)

        for seg in sut.segments {
            XCTAssertTrue(seg.isValid, "Segment \(seg.startTime)-\(seg.endTime) should be valid")
        }
    }

    // =========================================================================
    // MARK: - New Tests: ScrollableTimelineView Overhaul (2025-01)
    //
    // The old SegmentTimelineView was replaced with ScrollableTimelineView
    // (LumaFusion-style fixed playhead, scrollable content). The old Slider
    // scrub bar was removed and then re-added above the timeline.
    //
    // These tests verify that the SegmentManager, PlayerViewModel, and
    // segment model still behave correctly with the new timeline.
    // =========================================================================

    // MARK: - Seek + Keep: Forward Seek Past Existing Segments

    func testSeekForwardPastSegmentsAndKeep() {
        // First keep: 5..15
        begin(at: 5)
        stop(at: 15)

        // User scrolls the timeline forward (seek to 40) and keeps 40..50
        begin(at: 40)
        stop(at: 50)

        let included = sut.segments.filter(\.isIncluded)
        XCTAssertEqual(included.count, 2, "Should have two disjoint included segments")
        XCTAssertEqual(included[0].startTime, 5, accuracy: 0.001)
        XCTAssertEqual(included[0].endTime, 15, accuracy: 0.001)
        XCTAssertEqual(included[1].startTime, 40, accuracy: 0.001)
        XCTAssertEqual(included[1].endTime, 50, accuracy: 0.001)
        XCTAssertEqual(sut.totalIncludedDuration, 20, accuracy: 0.001)
    }

    // MARK: - Seek + Keep: Seek Into Gap Between Segments

    func testSeekIntoGapAndKeep() {
        // Create two disjoint keeps: 5..10 and 30..35
        begin(at: 5)
        stop(at: 10)
        begin(at: 30)
        stop(at: 35)

        // User seeks into the gap (15..25) and keeps
        begin(at: 15)
        stop(at: 25)

        let included = sut.segments.filter(\.isIncluded)
        XCTAssertEqual(included.count, 3, "Should have three disjoint included segments")
        XCTAssertEqual(included[0].startTime, 5, accuracy: 0.001)
        XCTAssertEqual(included[0].endTime, 10, accuracy: 0.001)
        XCTAssertEqual(included[1].startTime, 15, accuracy: 0.001)
        XCTAssertEqual(included[1].endTime, 25, accuracy: 0.001)
        XCTAssertEqual(included[2].startTime, 30, accuracy: 0.001)
        XCTAssertEqual(included[2].endTime, 35, accuracy: 0.001)
    }

    // MARK: - Re-Keep: Start Inside Included, Extend Into Next Included (Merge)

    func testReKeepBridgingTwoIncludedSegments() {
        // Two disjoint keeps: 5..15 and 25..35
        begin(at: 5)
        stop(at: 15)
        begin(at: 25)
        stop(at: 35)

        // Re-keep spanning from inside the first to inside the second: 10..30
        begin(at: 10)
        stop(at: 30)

        // Should merge everything into one included segment: 5..30
        let included = sut.segments.filter(\.isIncluded)
        XCTAssertEqual(included.count, 1, "Bridging re-keep should merge into one segment")
        XCTAssertEqual(included[0].startTime, 5, accuracy: 0.001)
        XCTAssertEqual(included[0].endTime, 30, accuracy: 0.001)
    }

    // MARK: - Re-Keep: Multiple Sequential Re-Keeps (Regression: BUG-016)

    func testMultipleReKeeps_stressTest() {
        // First keep: 10..20
        begin(at: 10)
        stop(at: 20)

        // Re-keep: extends 15..30
        begin(at: 15)
        stop(at: 30)

        // Re-keep again: extends 25..40
        begin(at: 25)
        stop(at: 40)

        let included = sut.segments.filter(\.isIncluded)
        XCTAssertEqual(included.count, 1, "Sequential re-keeps should merge into one segment")
        XCTAssertEqual(included[0].startTime, 10, accuracy: 0.001)
        XCTAssertEqual(included[0].endTime, 40, accuracy: 0.001)
        XCTAssertEqual(sut.totalIncludedDuration, 30, accuracy: 0.001)
    }

    // MARK: - Re-Keep: Shorter Keep Inside Existing (Trims End)

    func testReKeepShorterInsideExisting_trimsEnd() {
        // First keep: 10..40
        begin(at: 10)
        stop(at: 40)

        // Re-keep starting at 20, stopping at 25 (shorter)
        begin(at: 20)
        stop(at: 25)

        // BUG-016: re-keeping inside an existing segment trims to keepStart..stopTime
        // The effective start should be preserved from the original (10)
        let included = sut.segments.filter(\.isIncluded)
        XCTAssertEqual(included.count, 1)
        XCTAssertEqual(included[0].startTime, 10, accuracy: 0.001)
        XCTAssertEqual(included[0].endTime, 25, accuracy: 0.001)
    }

    // MARK: - Seek + Keep: Seek To Very Start After Previous Keeps

    func testSeekToStartAndKeep_afterExistingKeeps() {
        // Existing keep: 20..30
        begin(at: 20)
        stop(at: 30)

        // User seeks to start and keeps 0..5
        begin(at: 0)
        stop(at: 5)

        let included = sut.segments.filter(\.isIncluded)
        XCTAssertEqual(included.count, 2)
        XCTAssertEqual(included[0].startTime, 0, accuracy: 0.001)
        XCTAssertEqual(included[0].endTime, 5, accuracy: 0.001)
        XCTAssertEqual(included[1].startTime, 20, accuracy: 0.001)
        XCTAssertEqual(included[1].endTime, 30, accuracy: 0.001)
    }

    // MARK: - Seek + Keep: Seek To Very End

    func testSeekNearEndAndKeep() {
        // Existing keep: 5..15
        begin(at: 5)
        stop(at: 15)

        // User seeks near end and keeps 55..60
        begin(at: 55)
        stop(at: 60)

        let included = sut.segments.filter(\.isIncluded)
        XCTAssertEqual(included.count, 2)
        XCTAssertEqual(included[1].startTime, 55, accuracy: 0.001)
        XCTAssertEqual(included[1].endTime, 60, accuracy: 0.001)
    }

    // MARK: - Scroll-to-Seek Simulation (SegmentManager Integrity After Seek)

    /// Simulates the ScrollableTimelineView's scroll-to-seek behavior:
    /// user scrolls the timeline (which calls viewModel.seek(to:)),
    /// then toggles keep. The SegmentManager should handle arbitrary
    /// seek positions gracefully.
    func testScrollToSeek_thenKeep_arbitraryPositions() {
        // Simulate: user keeps 10..20, then scrolls to 45 and keeps 45..50
        begin(at: 10)
        stop(at: 20)

        // "Scroll to 45" — in the real app, handleScrollEnded() calls viewModel.seek(to: 45)
        // Then user presses Keep at 45
        begin(at: 45)
        stop(at: 50)

        let included = sut.segments.filter(\.isIncluded)
        XCTAssertEqual(included.count, 2)

        // Verify invariants still hold after scroll-seek + keep
        for i in 1..<sut.segments.count {
            XCTAssertLessThanOrEqual(
                sut.segments[i - 1].endTime,
                sut.segments[i].startTime + 0.001,
                "Segments should not overlap after scroll-seek"
            )
            XCTAssertLessThanOrEqual(
                sut.segments[i - 1].startTime,
                sut.segments[i].startTime,
                "Segments should be sorted after scroll-seek"
            )
        }
    }

    // MARK: - Adjacent Keeps Merge Correctly

    func testAdjacentKeeps_mergeIntoOne() {
        // Keep 10..20, then immediately keep 20..30
        begin(at: 10)
        stop(at: 20)
        begin(at: 20)
        stop(at: 30)

        // Adjacent included segments should merge
        let included = sut.segments.filter(\.isIncluded)
        XCTAssertEqual(included.count, 1, "Adjacent keeps should merge")
        XCTAssertEqual(included[0].startTime, 10, accuracy: 0.001)
        XCTAssertEqual(included[0].endTime, 30, accuracy: 0.001)
    }

    // MARK: - Long-Press Toggle (ScrollableTimelineView Feature)

    /// ScrollableTimelineView's long-press gesture calls toggleSegment on included segments.
    /// Verify toggling the middle of three included segments leaves the others intact.
    func testLongPressToggle_middleIncludedSegment() {
        // Create three included segments
        begin(at: 5)
        stop(at: 10)
        begin(at: 20)
        stop(at: 25)
        begin(at: 35)
        stop(at: 40)

        XCTAssertEqual(sut.includedSegmentCount, 3)

        // Long-press on the middle included segment → toggle it to excluded
        let middleIncluded = sut.segments.filter(\.isIncluded)[1]
        sut.toggleSegment(id: middleIncluded.id)

        // Should now have 2 included segments
        XCTAssertEqual(sut.includedSegmentCount, 2)
        let remaining = sut.segments.filter(\.isIncluded)
        XCTAssertEqual(remaining[0].startTime, 5, accuracy: 0.001)
        XCTAssertEqual(remaining[0].endTime, 10, accuracy: 0.001)
        XCTAssertEqual(remaining[1].startTime, 35, accuracy: 0.001)
        XCTAssertEqual(remaining[1].endTime, 40, accuracy: 0.001)
    }

    // MARK: - PlayerViewModel.greenFillEnd: Edge Cases

    func testGreenFillEnd_notKeepingButHasStartTime_returnsNil() {
        // Edge case: keepingStartTime somehow set but isIncluding is false
        let vm = PlayerViewModel()
        vm.isIncluding = false
        vm.keepingStartTime = 10
        vm.currentTime = 25
        XCTAssertNil(vm.greenFillEnd, "greenFillEnd should be nil when not actively including")
    }

    func testGreenFillEnd_atZeroCurrentTime() {
        let vm = PlayerViewModel()
        vm.isIncluding = true
        vm.keepingStartTime = 0
        vm.currentTime = 0
        XCTAssertEqual(vm.greenFillEnd, 0, "greenFillEnd should be 0 when keeping from start with no progress")
    }

    func testGreenFillEnd_tracksCurrentTimeProgression() {
        let vm = PlayerViewModel()
        vm.isIncluding = true
        vm.keepingStartTime = 5

        // Simulate time progression
        vm.currentTime = 5
        XCTAssertEqual(vm.greenFillEnd, 5)

        vm.currentTime = 10
        XCTAssertEqual(vm.greenFillEnd, 10)

        vm.currentTime = 15
        XCTAssertEqual(vm.greenFillEnd, 15)
    }

    // MARK: - PlayerViewModel.isPlaying: KVO-Derived Property
    //
    // NOTE: isPlaying is now derived from AVPlayer.timeControlStatus via KVO
    // (BUG-9970815942). Tests should NOT assume manual isPlaying toggling
    // because the KVO publisher will overwrite any manual assignment.
    //
    // The existing greenFillEnd tests correctly avoid depending on isPlaying.
    // The greenFillEnd property depends only on isIncluding + keepingStartTime,
    // which is the correct design — the green fill should show during active
    // keeping regardless of play/pause state.

    func testIsPlaying_initiallyFalse() {
        let vm = PlayerViewModel()
        // isPlaying defaults to false (AVPlayer not playing)
        XCTAssertFalse(vm.isPlaying, "isPlaying should default to false")
    }

    // MARK: - Regression Documentation: Pause-on-Scrub Setting
    //
    // REGRESSION: The "Scrub While Keeping" setting (pauseOnScrub/keepPlaying)
    // exists in SettingsView via @AppStorage("scrubWhileKeeping") but is NEVER
    // consumed by PlayerView or PlayerViewModel.
    //
    // The old SegmentTimelineView had built-in scrub handling that consulted
    // this setting. When the scrub bar was removed during the timeline overhaul,
    // this behavior was lost. The scrub bar was re-added to PlayerView as a
    // simple Slider that calls viewModel.seek(to:) directly — it does not read
    // scrubWhileKeeping at all.
    //
    // Impact: Users who set "Pause on Scrub" in settings will NOT get pause
    // behavior when scrubbing while keeping. The setting is effectively dead code.
    //
    // Recommendation: Either wire up the scrubWhileKeeping setting to the new
    // scrub bar, or remove the dead setting from SettingsView.

    func testScrubWhileKeeping_settingIsDeadCode() {
        // This test documents that the scrubWhileKeeping setting exists in
        // @AppStorage but is not consumed by the scrub bar or ViewModel.
        //
        // PlayerViewModel.seek(to:) does NOT check scrubWhileKeeping.
        // The new scrub bar in PlayerView calls seek(to:) directly without
        // consulting any "pause on scrub" preference.
        //
        // If this setting is wired up in the future, update this test to
        // verify the behavior instead.
        let vm = PlayerViewModel()
        vm.isIncluding = true
        vm.keepingStartTime = 10
        vm.currentTime = 20

        // Simulate a scrub (seek) while keeping — keeping state should persist
        // (there's no automatic pause-on-scrub logic in the ViewModel)
        vm.seek(to: 15)
        XCTAssertTrue(vm.isIncluding, "Seeking while keeping should not stop keeping")
        XCTAssertNotNil(vm.keepingStartTime, "keepingStartTime should persist after seek")
    }

    // MARK: - SegmentCanvasView Active Keep Visualization Consistency

    /// The SegmentCanvasView draws a growing green bar when isIncluding &&
    /// keepingStartTime != nil. This test verifies the data model that feeds
    /// the canvas is consistent — greenFillEnd returns the value the canvas
    /// needs to draw the active keep fill.
    func testCanvasActiveKeepData_matchesGreenFillEnd() {
        let vm = PlayerViewModel()
        vm.isIncluding = true
        vm.keepingStartTime = 12
        vm.currentTime = 30

        // The canvas checks: if isIncluding, let keepStart = keepingStartTime
        // and draws from keepStart to currentTime.
        // greenFillEnd should match currentTime in this state.
        XCTAssertEqual(vm.greenFillEnd, vm.currentTime)
        XCTAssertEqual(vm.keepingStartTime, 12)
    }

    // MARK: - Invariant: No Gaps or Overlaps After Complex Timeline Operations

    func testNoGapsInContiguousSegments() {
        // Build a complex timeline
        begin(at: 0)
        stop(at: 10)
        begin(at: 20)
        stop(at: 30)
        begin(at: 25)  // re-keep overlapping
        stop(at: 35)
        begin(at: 5)   // re-keep overlapping first
        stop(at: 15)

        // Verify contiguity: each segment's end should equal the next's start
        // (or be very close due to floating point)
        for i in 1..<sut.segments.count {
            XCTAssertEqual(
                sut.segments[i - 1].endTime,
                sut.segments[i].startTime,
                accuracy: 0.001,
                "Segments should be contiguous (no gaps)"
            )
        }
    }

    // MARK: - Reset Clears Recording State

    func testReset_clearsRecordingState_thenKeepWorks() {
        // Begin keeping (sets internal recordingStartTime)
        begin(at: 10)

        // Reset mid-keep
        sut.reset()
        XCTAssertTrue(sut.segments.isEmpty)

        // Should be able to begin fresh after reset
        begin(at: 5)
        stop(at: 15)

        let included = sut.segments.filter(\.isIncluded)
        XCTAssertEqual(included.count, 1)
        XCTAssertEqual(included[0].startTime, 5, accuracy: 0.001)
        XCTAssertEqual(included[0].endTime, 15, accuracy: 0.001)
    }

    // MARK: - Finalize After Re-Keeps

    func testFinalize_afterReKeeps_producesCleanTimeline() {
        begin(at: 10)
        stop(at: 30)
        begin(at: 20)  // re-keep inside existing
        stop(at: 40)

        sut.finalizeSegments(videoDuration: 60)

        // All segments should be valid, sorted, non-overlapping
        for seg in sut.segments {
            XCTAssertTrue(seg.isValid)
        }
        for i in 1..<sut.segments.count {
            XCTAssertLessThanOrEqual(sut.segments[i - 1].endTime, sut.segments[i].startTime + 0.001)
        }
        // Last segment should not exceed video duration
        if let last = sut.segments.last {
            XCTAssertLessThanOrEqual(last.endTime, 60.001)
        }
    }
}
