// Project.swift
// ClipCourt
//
// The root data model for a ClipCourt editing session.
// Stores a reference to the source video (PHAsset identifier),
// all toggle segments, and the last playback position for resume.
// "I'm Idaho!" — and this project is the WHOLE UNITED STATES of your edit.

import Foundation

struct Project: Codable, Identifiable, Equatable {

    // MARK: - Properties

    let id: UUID
    let assetIdentifier: String          // PHAsset.localIdentifier — no video copying
    var segments: [Segment]
    var lastPlaybackTime: Double         // Seconds from start, for session resume
    let createdAt: Date
    var modifiedAt: Date

    // MARK: - Initializer

    init(
        id: UUID = UUID(),
        assetIdentifier: String,
        segments: [Segment] = [],
        lastPlaybackTime: Double = 0,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.assetIdentifier = assetIdentifier
        self.segments = segments
        self.lastPlaybackTime = max(0, lastPlaybackTime)
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    // MARK: - Computed Properties

    /// Total duration of all included segments, in seconds.
    var includedDuration: Double {
        segments
            .filter(\.isIncluded)
            .reduce(0) { $0 + $1.duration }
    }

    /// Number of included segments.
    var includedSegmentCount: Int {
        segments.filter(\.isIncluded).count
    }

    /// Returns only the segments marked for inclusion, sorted by start time.
    var includedSegments: [Segment] {
        segments
            .filter(\.isIncluded)
            .sorted { $0.startTime < $1.startTime }
    }

    /// Whether the project has any included segments ready for export.
    var hasIncludedSegments: Bool {
        segments.contains { $0.isIncluded && $0.isValid }
    }

    /// Total duration covered by all segments (included + excluded).
    var totalSegmentedDuration: Double {
        guard let first = segments.min(by: { $0.startTime < $1.startTime }),
              let last = segments.max(by: { $0.endTime < $1.endTime }) else {
            return 0
        }
        return last.endTime - first.startTime
    }

    // MARK: - Mutation Helpers

    /// Touch the modification date whenever the project changes.
    mutating func touch() {
        modifiedAt = Date()
    }
}
