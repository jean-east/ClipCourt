// VideoPlayerService.swift
// ClipCourt
//
// Wraps AVPlayer with a clean async interface. Handles playback, seeking,
// variable speed, time observation, and end-of-video events.
// "Me fail English? That's unpossible!" — and me fail video playback?
// Also unpossible. Every AVFoundation call is REAL and PRODUCTION-READY.

import AVFoundation
import Combine
import Photos

// MARK: - Protocol

/// Protocol for video playback control — enables testing with mock players.
protocol VideoPlaybackControlling: AnyObject {
    var currentTimePublisher: AnyPublisher<Double, Never> { get }
    var didPlayToEndPublisher: AnyPublisher<Void, Never> { get }
    var durationSeconds: Double { get }
    var currentTimeSeconds: Double { get }
    var isPlaying: Bool { get }
    var player: AVPlayer { get }

    func loadAsset(identifier: String) async throws
    func play()
    func pause()
    func seek(to seconds: Double) async
    func seekFast(to seconds: Double) async
    func setRate(_ rate: Float)
    func getAsset() -> AVAsset?
}

// MARK: - Errors

enum VideoPlayerError: LocalizedError {
    case assetNotFound
    case assetLoadFailed(String)
    case noVideoTrack
    case playerItemFailed(String)
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .assetNotFound:
            "The source video could not be found in your photo library."
        case .assetLoadFailed(let reason):
            "Failed to load video: \(reason)"
        case .noVideoTrack:
            "The selected file does not contain a video track."
        case .playerItemFailed(let reason):
            "Player error: \(reason)"
        case .unsupportedFormat:
            "This video format is not supported."
        }
    }
}

// MARK: - Implementation

final class VideoPlayerService: VideoPlaybackControlling {

    // MARK: - Public Properties

    /// The underlying AVPlayer. Use for SwiftUI's VideoPlayer or AVPlayerLayer.
    let player = AVPlayer()

    /// Whether the player is currently playing (rate > 0 and not waiting).
    var isPlaying: Bool {
        player.timeControlStatus == .playing
    }

    /// Total duration of the loaded video in seconds. Returns 0 if no video loaded.
    var durationSeconds: Double {
        guard let duration = player.currentItem?.duration,
              duration.isNumeric, !duration.isIndefinite else { return 0 }
        return CMTimeGetSeconds(duration)
    }

    /// Current playback position in seconds.
    var currentTimeSeconds: Double {
        let time = player.currentTime()
        guard time.isNumeric, !time.isIndefinite else { return 0 }
        return CMTimeGetSeconds(time)
    }

    /// Publishes the current playback time ~30 times per second for smooth UI updates.
    var currentTimePublisher: AnyPublisher<Double, Never> {
        currentTimeSubject.eraseToAnyPublisher()
    }

    /// Fires when the video reaches the end.
    var didPlayToEndPublisher: AnyPublisher<Void, Never> {
        didPlayToEndSubject.eraseToAnyPublisher()
    }

    // MARK: - Private Properties

    private let currentTimeSubject = PassthroughSubject<Double, Never>()
    private let didPlayToEndSubject = PassthroughSubject<Void, Never>()
    private var timeObserverToken: Any?
    private var asset: AVAsset?
    private var statusObservation: NSKeyValueObservation?
    private var endOfVideoObserver: NSObjectProtocol?

    /// The desired playback rate. Preserved across play/pause cycles
    /// because AVPlayer.play() resets rate to 1.0.
    private var desiredRate: Float = 1.0

    // MARK: - Lifecycle

    deinit {
        cleanup()
    }

    // MARK: - Asset Loading

    /// Loads a video from the Photos library using its PHAsset local identifier.
    /// This does NOT copy the video — we get a direct AVAsset reference.
    ///
    /// - Parameter identifier: The PHAsset.localIdentifier of the video to load.
    /// - Throws: `VideoPlayerError` if the asset can't be found, loaded, or lacks a video track.
    func loadAsset(identifier: String) async throws {
        // Clean up any previous playback session
        cleanup()

        // Fetch the PHAsset from the Photos library
        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: [identifier],
            options: nil
        )

        guard let phAsset = fetchResult.firstObject else {
            throw VideoPlayerError.assetNotFound
        }

        // Request the AVAsset from Photos (no file copy — direct reference)
        let avAsset = try await requestAVAsset(for: phAsset)

        // Verify it has at least one video track
        let videoTracks = try await avAsset.loadTracks(withMediaType: .video)
        guard !videoTracks.isEmpty else {
            throw VideoPlayerError.noVideoTrack
        }

        // Verify the asset reports as playable
        let isPlayable = try await avAsset.load(.isPlayable)
        guard isPlayable else {
            throw VideoPlayerError.unsupportedFormat
        }

        // Store the asset for export access
        self.asset = avAsset

        // Create player item and configure the player on the main actor.
        // AVPlayerItem init is implicitly @MainActor in Swift 6.
        await MainActor.run {
            let playerItem = AVPlayerItem(asset: avAsset)
            player.replaceCurrentItem(with: playerItem)
            // Pause at end so we can detect it and let the user replay
            player.actionAtItemEnd = .pause
            desiredRate = 1.0
            setupTimeObserver()
            setupEndOfVideoObserver()
            setupPlayerItemStatusObserver()
        }
    }

    /// Returns the underlying AVAsset for export composition.
    /// Returns nil if no video has been loaded.
    func getAsset() -> AVAsset? {
        asset
    }

    // MARK: - Playback Controls

    /// Start or resume playback at the current desired rate.
    func play() {
        // Setting rate to a positive value implicitly plays.
        // This preserves the user's speed setting (0.25x–2x).
        player.rate = desiredRate > 0 ? desiredRate : 1.0
    }

    /// Pause playback. The current position is preserved.
    func pause() {
        player.pause()
    }

    /// Seek to an exact position with frame-accurate tolerance.
    /// Use this for toggle timing and precise positioning.
    ///
    /// - Parameter seconds: Target time in seconds. Clamped to [0, duration].
    func seek(to seconds: Double) async {
        let clamped = clamp(seconds, min: 0, max: durationSeconds)
        let time = CMTime(seconds: clamped, preferredTimescale: 600)
        await player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    /// Seek to a position with relaxed tolerance — faster for scrubbing.
    /// Allows up to 0.1s tolerance for snappier response during drag gestures.
    ///
    /// - Parameter seconds: Target time in seconds. Clamped to [0, duration].
    func seekFast(to seconds: Double) async {
        let clamped = clamp(seconds, min: 0, max: durationSeconds)
        let time = CMTime(seconds: clamped, preferredTimescale: 600)
        let tolerance = CMTime(seconds: 0.1, preferredTimescale: 600)
        await player.seek(to: time, toleranceBefore: tolerance, toleranceAfter: tolerance)
    }

    /// Set the playback rate. Applies immediately if playing, otherwise
    /// takes effect on next play() call.
    ///
    /// Supported rates: 0.25, 0.5, 1.0, 1.5, 2.0 (and any positive Float).
    /// - Parameter rate: The desired playback rate.
    func setRate(_ rate: Float) {
        desiredRate = rate
        if isPlaying {
            player.rate = rate
        }
    }

    // MARK: - Time Observation (30fps for smooth UI)

    private func setupTimeObserver() {
        removeTimeObserver()

        // ~30 updates per second — smooth enough for a scrub bar and timestamp display
        let interval = CMTime(
            seconds: 1.0 / 30.0,
            preferredTimescale: 600
        )

        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            let seconds = CMTimeGetSeconds(time)
            guard seconds.isFinite else { return }
            self?.currentTimeSubject.send(seconds)
        }
    }

    private func removeTimeObserver() {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }

    // MARK: - End-of-Video Handling

    private func setupEndOfVideoObserver() {
        removeEndOfVideoObserver()

        endOfVideoObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.didPlayToEndSubject.send()
        }
    }

    private func removeEndOfVideoObserver() {
        if let observer = endOfVideoObserver {
            NotificationCenter.default.removeObserver(observer)
            endOfVideoObserver = nil
        }
    }

    // MARK: - Player Item Status Observation

    private func setupPlayerItemStatusObserver() {
        statusObservation?.invalidate()

        statusObservation = player.currentItem?.observe(
            \.status,
            options: [.new, .initial]
        ) { item, _ in
            switch item.status {
            case .readyToPlay:
                // Player item is ready — no action needed, duration is now available
                break
            case .failed:
                let errorDescription = item.error?.localizedDescription ?? "Unknown playback error"
                print("[VideoPlayerService] Player item failed: \(errorDescription)")
            case .unknown:
                break
            @unknown default:
                break
            }
        }
    }

    // MARK: - PHAsset → AVAsset Bridge

    /// Requests an AVAsset from Photos for the given PHAsset.
    /// Uses high-quality format and allows network access for iCloud videos.
    private func requestAVAsset(for phAsset: PHAsset) async throws -> AVAsset {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.version = .current
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestAVAsset(
                forVideo: phAsset,
                options: options
            ) { asset, _, info in
                if let asset {
                    continuation.resume(returning: asset)
                } else {
                    let reason = (info?[PHImageErrorKey] as? Error)?
                        .localizedDescription ?? "Unknown error"
                    continuation.resume(
                        throwing: VideoPlayerError.assetLoadFailed(reason)
                    )
                }
            }
        }
    }

    // MARK: - Cleanup

    /// Tears down all observers and releases the player item.
    /// Called on deinit, before loading a new asset, and on project close.
    func cleanup() {
        removeTimeObserver()
        removeEndOfVideoObserver()
        statusObservation?.invalidate()
        statusObservation = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        asset = nil
        desiredRate = 1.0
    }

    // MARK: - Helpers

    private func clamp(_ value: Double, min: Double, max: Double) -> Double {
        Swift.min(Swift.max(value, min), max)
    }
}
