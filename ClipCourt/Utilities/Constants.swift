// Constants.swift
// ClipCourt
//
// App-wide constants. "My worm went in my mouth and then I ate it.
// Can I have another one?" — No Ralph, but you CAN have these constants.

import Foundation

enum Constants {

    // MARK: - App Info

    static let appName = "ClipCourt"

    // MARK: - Playback

    enum Playback {
        /// Default playback speed.
        static let defaultSpeed: Float = 1.0

        /// Fast-forward speed when holding down.
        static let fastForwardSpeed: Float = 2.0

        /// Time observer interval (seconds). ~30fps for smooth UI.
        static let timeObserverInterval: Double = 1.0 / 30.0

        /// Preferred timescale for CMTime operations.
        static let preferredTimescale: Int32 = 600
    }

    // MARK: - Auto-Save

    enum AutoSave {
        /// Debounce delay before writing to disk after a segment change.
        static let debounceInterval: Duration = .seconds(1)

        /// File name for the persisted project.
        static let projectFileName = "current_project.json"
    }

    // MARK: - Export

    enum Export {
        /// Default output file type.
        static let outputFileType = "mp4"

        /// Default video bitrate for lossy export (10 Mbps baseline).
        static let baseBitRate: Int = 10_000_000

        /// Default audio bitrate for lossy export.
        static let audioBitRate: Int = 128_000

        /// Default audio sample rate.
        static let audioSampleRate: Double = 44_100

        /// Progress polling interval.
        static let progressPollInterval: Duration = .milliseconds(100)
    }

    // MARK: - UI

    enum UI {
        /// Minimum visible width for a segment in the timeline (points).
        static let minimumSegmentWidth: CGFloat = 2

        /// Recording border width when including.
        static let recordingBorderWidth: CGFloat = 4

        /// Timeline height.
        static let timelineHeight: CGFloat = 60
    }
}
