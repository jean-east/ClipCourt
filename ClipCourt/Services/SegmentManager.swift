// SegmentManager.swift
// ClipCourt
//
// Manages the ordered list of include/exclude segments.
// "When I grow up, I'm going to Bovine University!" — and THIS
// manager will be there, keeping my segments in order.

import Foundation

/// Protocol for segment management — enables testing.
protocol SegmentManaging {
    var segments: [Segment] { get }
    func beginIncluding(at time: Double, videoDuration: Double) -> [Segment]
    func stopIncluding(at time: Double) -> [Segment]
    func toggleSegment(id: UUID) -> [Segment]
    func segment(at time: Double) -> Segment?
    func replaceSegments(_ segments: [Segment])
}

// MARK: - Implementation

final class SegmentManager: SegmentManaging {

    // MARK: - State

    private(set) var segments: [Segment] = []

    // MARK: - Toggle Operations

    /// Begin including content at the given playback time.
    /// Splits the current excluded region and inserts a new included segment.
    func beginIncluding(at time: Double, videoDuration: Double) -> [Segment] {
        // Close any prior excluded segment at this point and start an included one
        // The included segment's endTime is initially set to video duration;
        // it will be closed when stopIncluding is called.

        if segments.isEmpty {
            // First interaction: if toggling on after start, create an excluded
            // segment from 0 to now, then an included segment from now onward.
            if time > 0 {
                segments.append(Segment(
                    startTime: 0,
                    endTime: time,
                    isIncluded: false
                ))
            }
            segments.append(Segment(
                startTime: time,
                endTime: videoDuration,
                isIncluded: true
            ))
        } else if let lastIndex = segments.indices.last {
            // Close the current last segment at this time
            var lastSegment = segments[lastIndex]
            if !lastSegment.isIncluded {
                lastSegment.endTime = time
                segments[lastIndex] = lastSegment

                // Start a new included segment
                segments.append(Segment(
                    startTime: time,
                    endTime: videoDuration,
                    isIncluded: true
                ))
            }
            // If already included, no-op (shouldn't happen with proper toggle logic)
        }

        return segments
    }

    /// Stop including content at the given playback time.
    /// Closes the current included segment and begins an excluded one.
    func stopIncluding(at time: Double) -> [Segment] {
        guard let lastIndex = segments.indices.last else { return segments }

        var lastSegment = segments[lastIndex]
        guard lastSegment.isIncluded else { return segments }

        // Close the included segment
        lastSegment.endTime = time
        segments[lastIndex] = lastSegment

        // The remaining portion becomes excluded (endTime set to video duration or
        // will be adjusted when next toggle occurs)
        // We create an "open" excluded segment — its endTime is tentative.
        // It will be capped to video duration on export.
        segments.append(Segment(
            startTime: time,
            endTime: lastSegment.endTime, // Will be updated
            isIncluded: false
        ))

        return segments
    }

    /// Toggle the isIncluded state of a specific segment (for retroactive editing).
    func toggleSegment(id: UUID) -> [Segment] {
        guard let index = segments.firstIndex(where: { $0.id == id }) else {
            return segments
        }

        segments[index].isIncluded.toggle()

        // Merge adjacent segments with the same state
        mergeAdjacentSegments()

        return segments
    }

    /// Find the segment containing the given playback time.
    func segment(at time: Double) -> Segment? {
        segments.first { $0.contains(time: time) }
    }

    /// Replace all segments (used when restoring from persistence).
    func replaceSegments(_ newSegments: [Segment]) {
        segments = newSegments.sorted()
    }

    // MARK: - Finalization

    /// Cap the last segment's endTime to the actual video duration.
    /// Call this when the video duration becomes known or before export.
    func finalizeSegments(videoDuration: Double) -> [Segment] {
        guard !segments.isEmpty else { return segments }

        // Ensure the last segment ends at video duration
        if var last = segments.last, last.endTime != videoDuration {
            last.endTime = videoDuration
            segments[segments.count - 1] = last
        }

        // Remove any zero-duration segments
        segments.removeAll { !$0.isValid }

        return segments
    }

    // MARK: - Merge Logic

    /// Merge adjacent segments that share the same isIncluded state.
    private func mergeAdjacentSegments() {
        guard segments.count > 1 else { return }

        var merged: [Segment] = [segments[0]]

        for i in 1..<segments.count {
            let current = segments[i]
            var previous = merged[merged.count - 1]

            if previous.isIncluded == current.isIncluded {
                // Merge: extend previous to cover current
                previous.endTime = current.endTime
                merged[merged.count - 1] = previous
            } else {
                merged.append(current)
            }
        }

        segments = merged
    }
}
