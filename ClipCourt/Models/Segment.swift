// Segment.swift
// ClipCourt
//
// A time range within the source video, marked as included or excluded.
// Segments are the fundamental editing unit: toggle on creates one,
// toggle off closes it.

import Foundation

struct Segment: Codable, Identifiable, Equatable, Hashable {

    // MARK: - Properties

    let id: UUID
    var startTime: Double       // Seconds from video start
    var endTime: Double         // Seconds from video start
    var isIncluded: Bool

    // MARK: - Initializer

    init(
        id: UUID = UUID(),
        startTime: Double,
        endTime: Double,
        isIncluded: Bool
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.isIncluded = isIncluded
    }

    // MARK: - Computed Properties

    /// Duration of this segment in seconds.
    var duration: Double {
        max(0, endTime - startTime)
    }

    /// Whether this segment has a valid (non-zero) time range.
    var isValid: Bool {
        endTime > startTime
    }

    /// Returns true if this segment contains the given time (inclusive of start, exclusive of end).
    func contains(time: Double) -> Bool {
        time >= startTime && time < endTime
    }
}

// MARK: - Comparable (sort by start time)

extension Segment: Comparable {
    static func < (lhs: Segment, rhs: Segment) -> Bool {
        lhs.startTime < rhs.startTime
    }
}
