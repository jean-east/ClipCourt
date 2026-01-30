// Segment.swift
// ClipCourt
//
// A time range within the source video, marked as included or excluded.
// Segments are the fundamental editing unit: toggle on creates one,
// toggle off closes it. "I found a moon rock in my nose!" — and I
// found a CMTimeRange in my Segment.

import CoreMedia
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
        self.startTime = max(0, startTime)
        self.endTime = max(0, endTime)
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

    /// CoreMedia time range for use with AVFoundation composition/export.
    /// Uses 600 timescale (standard for video — divisible by 24, 25, 30, 60 fps).
    var timeRange: CMTimeRange {
        let start = CMTime(seconds: startTime, preferredTimescale: 600)
        let end = CMTime(seconds: endTime, preferredTimescale: 600)
        return CMTimeRange(start: start, end: end)
    }

    /// Start time as CMTime.
    var cmStartTime: CMTime {
        CMTime(seconds: startTime, preferredTimescale: 600)
    }

    /// End time as CMTime.
    var cmEndTime: CMTime {
        CMTime(seconds: endTime, preferredTimescale: 600)
    }

    /// Duration as CMTime.
    var cmDuration: CMTime {
        CMTime(seconds: duration, preferredTimescale: 600)
    }

    /// Returns true if this segment contains the given time (inclusive of start, exclusive of end).
    func contains(time: Double) -> Bool {
        time >= startTime && time < endTime
    }

    /// Returns true if this segment overlaps with another segment.
    func overlaps(with other: Segment) -> Bool {
        startTime < other.endTime && endTime > other.startTime
    }

    /// Returns true if this segment is adjacent to another (end touches start or vice versa).
    func isAdjacent(to other: Segment) -> Bool {
        abs(endTime - other.startTime) < 0.001 || abs(other.endTime - startTime) < 0.001
    }
}

// MARK: - Comparable (sort by start time)

extension Segment: Comparable {
    static func < (lhs: Segment, rhs: Segment) -> Bool {
        lhs.startTime < rhs.startTime
    }
}
