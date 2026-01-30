// Project.swift
// ClipCourt
//
// The root data model for a ClipCourt editing session.
// Stores a reference to the source video (PHAsset identifier),
// all toggle segments, and the last playback position for resume.

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
        self.lastPlaybackTime = lastPlaybackTime
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

    /// Returns only the segments marked for inclusion, sorted by start time.
    var includedSegments: [Segment] {
        segments
            .filter(\.isIncluded)
            .sorted { $0.startTime < $1.startTime }
    }

    // MARK: - Mutation Helpers

    /// Touch the modification date whenever the project changes.
    mutating func touch() {
        modifiedAt = Date()
    }
}
