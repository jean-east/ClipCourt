// SegmentManager.swift
// ClipCourt
//
// Manages the ordered list of include/exclude segments.
// "When I grow up, I'm going to Bovine University!" — and THIS
// manager will be there, keeping my segments in PERFECT order.
//
// Key invariant: segments are always sorted by startTime and never overlap.
// They tile the portion of the video that's been interacted with.
// The toggle model: ON splits the current excluded region, OFF splits
// the current included region. Works for linear playback AND seek-back.

import Foundation

// MARK: - Protocol

/// Protocol for segment management — enables testing.
protocol SegmentManaging {
    var segments: [Segment] { get }
    var totalIncludedDuration: Double { get }
    func beginIncluding(at time: Double, videoDuration: Double) -> [Segment]
    func stopIncluding(at time: Double) -> [Segment]
    func toggleSegment(id: UUID) -> [Segment]
    func splitSegment(at time: Double) -> [Segment]
    func segment(at time: Double) -> Segment?
    func replaceSegments(_ segments: [Segment])
    func finalizeSegments(videoDuration: Double) -> [Segment]
}

// MARK: - Implementation

final class SegmentManager: SegmentManaging {

    // MARK: - State

    /// The ordered array of segments covering the video timeline.
    /// Invariant: sorted by startTime, non-overlapping, tiling contiguous ranges.
    private(set) var segments: [Segment] = []

    /// BUG-016: Tracks where the current recording session started.
    /// Set by `beginIncluding()`, consumed by `stopIncluding()` for range replacement.
    /// When non-nil, `stopIncluding()` replaces the entire `[recordingStartTime, stopTime]`
    /// range with a single included segment instead of acting on a single point.
    private var recordingStartTime: Double?

    // MARK: - Computed Properties

    /// Total duration of all included segments, in seconds.
    var totalIncludedDuration: Double {
        segments
            .filter(\.isIncluded)
            .reduce(0) { $0 + $1.duration }
    }

    /// Total number of included segments.
    var includedSegmentCount: Int {
        segments.filter(\.isIncluded).count
    }

    // MARK: - Begin Including (Toggle ON)

    /// Begin including content at the given playback time.
    ///
    /// Behavior depends on context:
    /// - **No segments yet:** Initializes the timeline with [0..time excluded][time..end included]
    /// - **Inside an excluded segment:** Splits it at `time` — first half stays excluded,
    ///   second half becomes included.
    /// - **Inside an included segment:** Records start time for range replacement (BUG-016).
    /// - **Beyond all segments:** Extends or creates a new included segment to video end.
    ///
    /// BUG-016: Always stores `recordingStartTime` so that `stopIncluding()` can perform
    /// a range replacement — overwriting all segments in [start, stop] with one included
    /// segment. This implements tape-recorder semantics: re-recording over existing clips
    /// replaces them.
    ///
    /// Adjacent same-state segments may temporarily coexist during active recording.
    /// They are merged when the recording closes (stopIncluding, toggleSegment,
    /// or finalizeSegments). This preserves pre-existing segment boundaries. (BUG-014)
    ///
    /// - Parameters:
    ///   - time: Current playback time in seconds.
    ///   - videoDuration: Total video duration in seconds (needed for the open-ended segment).
    /// - Returns: Updated segments array.
    @discardableResult
    func beginIncluding(at time: Double, videoDuration: Double) -> [Segment] {
        guard videoDuration > 0 else { return segments }
        let t = clamp(time, min: 0, max: videoDuration)

        // BUG-016: Always store recording start time for range replacement on stop.
        // This enables tape-recorder semantics — re-recording over existing segments
        // overwrites them instead of leaving fragments.
        recordingStartTime = t

        if segments.isEmpty {
            // First interaction: initialize the full timeline
            initializeTimeline(at: t, videoDuration: videoDuration, startIncluded: true)
        } else if let index = segmentIndex(containing: t) {
            // Inside an existing segment
            let seg = segments[index]
            if !seg.isIncluded {
                // Split the excluded segment: [start..t excluded] [t..end included]
                splitAndSetIncluded(at: t, index: index, setIncluded: true)
            }
            // BUG-016: If already included, no split needed — recordingStartTime is
            // stored above, so stopIncluding() will handle the full range replacement.
        } else if t >= (segments.last?.endTime ?? 0) {
            // Beyond all segments — extend to video end
            let lastEnd = segments.last?.endTime ?? 0
            if t > lastEnd {
                // Gap between last segment and current time — fill with excluded
                segments.append(Segment(startTime: lastEnd, endTime: t, isIncluded: false))
            }
            segments.append(Segment(startTime: t, endTime: videoDuration, isIncluded: true))
        }

        // BUG-014 fix: only remove zero-duration segments and sort.
        // Skip mergeAdjacentSegments() to preserve existing segment boundaries
        // while a recording is in progress.
        cleanupWithoutMerge()
        return segments
    }

    // MARK: - Stop Including (Toggle OFF)

    /// Stop including content at the given playback time.
    ///
    /// BUG-016: When `recordingStartTime` is set (from a prior `beginIncluding` call),
    /// performs a **range replacement**: all segments overlapping `[recordingStartTime, time]`
    /// are trimmed or removed, and a single included segment is inserted for the recorded
    /// range. This implements tape-recorder semantics — re-recording over existing clips
    /// replaces them cleanly.
    ///
    /// Fallback behavior (no `recordingStartTime`):
    /// - **Inside an included segment:** Splits it at `time` — first half stays included,
    ///   second half becomes excluded.
    /// - **Inside an excluded segment:** No-op (already excluding).
    /// - **No segments:** No-op.
    ///
    /// Adjacent segments with the same state are automatically merged.
    ///
    /// - Parameter time: Current playback time in seconds.
    /// - Returns: Updated segments array.
    @discardableResult
    func stopIncluding(at time: Double) -> [Segment] {
        guard !segments.isEmpty else { return segments }

        if let startTime = recordingStartTime {
            // BUG-016: Range replacement — overwrite all segments in [start, stop]
            // with a single included segment. Trim partially overlapping segments,
            // remove fully contained ones.
            replaceRange(from: startTime, to: time)
            recordingStartTime = nil
        } else {
            // Fallback: point-in-time split (e.g., restored session without recordingStartTime)
            if let index = segmentIndex(containing: time) {
                let seg = segments[index]
                if !seg.isIncluded {
                    // Already excluded — no-op
                    return segments
                }
                // Split the included segment: [start..time included] [time..end excluded]
                splitAndSetIncluded(at: time, index: index, setIncluded: false)
            }
        }
        // If time is outside all segments, nothing to stop

        cleanup()
        return segments
    }

    // MARK: - Toggle Specific Segment

    /// Toggle the isIncluded state of a specific segment by ID.
    /// Used for retroactive editing from the timeline view.
    ///
    /// Adjacent segments with the same state are automatically merged afterward.
    ///
    /// - Parameter id: The UUID of the segment to toggle.
    /// - Returns: Updated segments array.
    @discardableResult
    func toggleSegment(id: UUID) -> [Segment] {
        guard let index = segments.firstIndex(where: { $0.id == id }) else {
            return segments
        }

        segments[index].isIncluded.toggle()
        cleanup()
        return segments
    }

    // MARK: - Split Segment

    /// Split the segment at the given time into two segments with the same state.
    /// Useful for future fine-grained editing.
    ///
    /// - Parameter time: The time at which to split.
    /// - Returns: Updated segments array.
    @discardableResult
    func splitSegment(at time: Double) -> [Segment] {
        guard let index = segmentIndex(containing: time) else {
            return segments
        }

        let original = segments[index]

        // Don't split at boundaries — must be strictly inside
        guard time > original.startTime && time < original.endTime else {
            return segments
        }

        let firstHalf = Segment(
            startTime: original.startTime,
            endTime: time,
            isIncluded: original.isIncluded
        )
        let secondHalf = Segment(
            startTime: time,
            endTime: original.endTime,
            isIncluded: original.isIncluded
        )

        segments.replaceSubrange(index...index, with: [firstHalf, secondHalf])
        return segments
    }

    // MARK: - Query

    /// Find the segment containing the given playback time.
    ///
    /// - Parameter time: Playback time in seconds.
    /// - Returns: The segment at that time, or nil if no segment covers it.
    func segment(at time: Double) -> Segment? {
        segments.first { $0.contains(time: time) }
    }

    // MARK: - Bulk Operations

    /// Replace all segments (used when restoring from persistence).
    /// Segments are sorted and validated. Clears any active recording session.
    func replaceSegments(_ newSegments: [Segment]) {
        segments = newSegments.sorted()
        recordingStartTime = nil
    }

    /// Cap the last segment's endTime to the actual video duration
    /// and remove any zero-duration segments.
    /// Call this when the video duration becomes known or before export.
    @discardableResult
    func finalizeSegments(videoDuration: Double) -> [Segment] {
        guard !segments.isEmpty else { return segments }

        // Cap any segment that extends beyond video duration
        for i in segments.indices {
            if segments[i].endTime > videoDuration {
                segments[i].endTime = videoDuration
            }
        }

        // Remove zero-duration or invalid segments
        segments.removeAll { !$0.isValid }

        // Re-merge in case capping created adjacent same-state segments
        mergeAdjacentSegments()

        return segments
    }

    /// Remove all segments and reset to empty state.
    func reset() {
        segments = []
        recordingStartTime = nil
    }

    // MARK: - Private: Range Replacement (BUG-016)

    /// Replace all segments overlapping the range `[from, to]` with a single included segment.
    ///
    /// Segments fully inside the range are removed. Segments partially overlapping are
    /// trimmed to the non-overlapping portion. Segments fully containing the range are
    /// split into two remnants (before and after). This implements tape-recorder semantics:
    /// recording over existing clips erases and replaces them.
    ///
    /// - Parameters:
    ///   - from: Start of the recorded range (seconds).
    ///   - to: End of the recorded range (seconds).
    private func replaceRange(from: Double, to: Double) {
        let rangeStart = min(from, to)
        let rangeEnd = max(from, to)

        // Zero-length recording — nothing to replace
        guard rangeEnd > rangeStart else { return }

        var newSegments: [Segment] = []

        for seg in segments {
            if seg.endTime <= rangeStart || seg.startTime >= rangeEnd {
                // Completely outside the range — keep as-is
                newSegments.append(seg)
            } else if seg.startTime < rangeStart && seg.endTime > rangeEnd {
                // Fully contains the range — split into two remnants
                newSegments.append(Segment(
                    startTime: seg.startTime, endTime: rangeStart,
                    isIncluded: seg.isIncluded
                ))
                newSegments.append(Segment(
                    startTime: rangeEnd, endTime: seg.endTime,
                    isIncluded: seg.isIncluded
                ))
            } else if seg.startTime < rangeStart {
                // Overlaps from the left — trim to end before range
                newSegments.append(Segment(
                    startTime: seg.startTime, endTime: rangeStart,
                    isIncluded: seg.isIncluded
                ))
            } else if seg.endTime > rangeEnd {
                // Overlaps from the right — trim to start after range
                newSegments.append(Segment(
                    startTime: rangeEnd, endTime: seg.endTime,
                    isIncluded: seg.isIncluded
                ))
            }
            // else: fully contained within the range — remove (don't add)
        }

        // Insert the new included segment for the recorded range
        newSegments.append(Segment(
            startTime: rangeStart, endTime: rangeEnd, isIncluded: true
        ))

        // Sort to maintain invariant
        newSegments.sort()

        segments = newSegments
    }

    // MARK: - Private: Timeline Initialization

    /// Creates the initial segment layout when the user first toggles.
    private func initializeTimeline(at time: Double, videoDuration: Double, startIncluded: Bool) {
        segments = []

        if time > 0 {
            segments.append(Segment(
                startTime: 0,
                endTime: time,
                isIncluded: !startIncluded
            ))
        }

        segments.append(Segment(
            startTime: time,
            endTime: videoDuration,
            isIncluded: startIncluded
        ))
    }

    // MARK: - Private: Split and Set State

    /// Splits the segment at `index` at the given time. The portion BEFORE `time`
    /// keeps its original state. The portion FROM `time` onward gets `setIncluded`.
    private func splitAndSetIncluded(at time: Double, index: Int, setIncluded: Bool) {
        let original = segments[index]

        if time <= original.startTime {
            // At or before the start — just change the whole segment's state
            segments[index].isIncluded = setIncluded
            return
        }

        if time >= original.endTime {
            // At or past the end — nothing to split
            return
        }

        // Split: [original.start .. time (original state)] [time .. original.end (new state)]
        let firstHalf = Segment(
            startTime: original.startTime,
            endTime: time,
            isIncluded: original.isIncluded
        )
        let secondHalf = Segment(
            startTime: time,
            endTime: original.endTime,
            isIncluded: setIncluded
        )

        segments.replaceSubrange(index...index, with: [firstHalf, secondHalf])
    }

    // MARK: - Private: Segment Lookup

    /// Find the index of the segment containing the given time.
    /// Uses the segment's `contains(time:)` which is [start, end).
    /// Falls back to the last segment if time equals its endTime.
    private func segmentIndex(containing time: Double) -> Int? {
        if let index = segments.firstIndex(where: { $0.contains(time: time) }) {
            return index
        }

        // Edge case: time is exactly at the end of the last segment
        if let last = segments.last, abs(time - last.endTime) < 0.001 {
            return segments.count - 1
        }

        return nil
    }

    // MARK: - Private: Cleanup

    /// Removes invalid segments and merges adjacent same-state segments.
    private func cleanup() {
        cleanupWithoutMerge()

        // Merge adjacent same-state segments
        mergeAdjacentSegments()
    }

    /// Lightweight cleanup: removes zero-duration segments and sorts,
    /// but does NOT merge adjacent same-state segments.
    ///
    /// Used during `beginIncluding()` to preserve segment boundaries while
    /// a recording is in progress. Merging is deferred to `stopIncluding()`,
    /// `toggleSegment()`, and `finalizeSegments()`. (BUG-014 fix)
    private func cleanupWithoutMerge() {
        // Remove zero-duration segments
        segments.removeAll { !$0.isValid }

        // Sort (should already be sorted, but enforce invariant)
        segments.sort()
    }

    // MARK: - Private: Merge Logic

    /// Merge adjacent segments that share the same `isIncluded` state.
    /// Also handles overlapping segments (shouldn't happen, but defensive).
    private func mergeAdjacentSegments() {
        guard segments.count > 1 else { return }

        var merged: [Segment] = [segments[0]]

        for i in 1..<segments.count {
            let current = segments[i]
            var previous = merged[merged.count - 1]

            // Merge if same state AND (adjacent or overlapping)
            // Adjacent: previous.endTime ≈ current.startTime (within 1ms tolerance)
            // Overlapping: current.startTime < previous.endTime
            let isAdjacentOrOverlapping = current.startTime <= previous.endTime + 0.001

            if previous.isIncluded == current.isIncluded && isAdjacentOrOverlapping {
                // Extend previous to cover current
                previous.endTime = max(previous.endTime, current.endTime)
                merged[merged.count - 1] = previous
            } else {
                merged.append(current)
            }
        }

        segments = merged
    }

    // MARK: - Private: Helpers

    private func clamp(_ value: Double, min: Double, max: Double) -> Double {
        Swift.min(Swift.max(value, min), max)
    }
}
