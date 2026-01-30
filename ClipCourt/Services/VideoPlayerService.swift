// VideoPlayerService.swift
// ClipCourt
//
// Wraps AVPlayer with a clean async interface. Handles playback, seeking,
// variable speed, and time observation. "Me fail English? That's unpossible!"
// But me fail video playback? Also unpossible.

import AVFoundation
import Combine
import Photos

/// Protocol for video playback control — enables testing with mock players.
protocol VideoPlaybackControlling: AnyObject {
    var currentTimePublisher: AnyPublisher<Double, Never> { get }
    var durationSeconds: Double { get }
    var isPlaying: Bool { get }
    var player: AVPlayer { get }

    func loadAsset(identifier: String) async throws
    func play()
    func pause()
    func seek(to seconds: Double) async
    func setRate(_ rate: Float)
}

// MARK: - Errors

enum VideoPlayerError: LocalizedError {
    case assetNotFound
    case assetLoadFailed(String)
    case noVideoTrack

    var errorDescription: String? {
        switch self {
        case .assetNotFound:
            "The source video could not be found in your photo library."
        case .assetLoadFailed(let reason):
            "Failed to load video: \(reason)"
        case .noVideoTrack:
            "The selected file does not contain a video track."
        }
    }
}

// MARK: - Implementation

final class VideoPlayerService: VideoPlaybackControlling {

    // MARK: - Public Properties

    let player = AVPlayer()

    var isPlaying: Bool {
        player.timeControlStatus == .playing
    }

    var durationSeconds: Double {
        guard let duration = player.currentItem?.duration,
              duration.isNumeric else { return 0 }
        return CMTimeGetSeconds(duration)
    }

    var currentTimePublisher: AnyPublisher<Double, Never> {
        currentTimeSubject.eraseToAnyPublisher()
    }

    // MARK: - Private Properties

    private let currentTimeSubject = PassthroughSubject<Double, Never>()
    private var timeObserverToken: Any?
    private var asset: AVAsset?

    // MARK: - Lifecycle

    deinit {
        removeTimeObserver()
    }

    // MARK: - Asset Loading

    /// Loads a video from the Photos library using its PHAsset local identifier.
    /// This does NOT copy the video — we get a direct reference.
    func loadAsset(identifier: String) async throws {
        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: [identifier],
            options: nil
        )

        guard let phAsset = fetchResult.firstObject else {
            throw VideoPlayerError.assetNotFound
        }

        let avAsset = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AVAsset, Error>) in
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
                    let reason = (info?[PHImageErrorKey] as? Error)?.localizedDescription ?? "Unknown error"
                    continuation.resume(throwing: VideoPlayerError.assetLoadFailed(reason))
                }
            }
        }

        // Verify it has a video track
        let videoTracks = try await avAsset.loadTracks(withMediaType: .video)
        guard !videoTracks.isEmpty else {
            throw VideoPlayerError.noVideoTrack
        }

        self.asset = avAsset
        let playerItem = AVPlayerItem(asset: avAsset)
        await MainActor.run {
            player.replaceCurrentItem(with: playerItem)
            setupTimeObserver()
        }
    }

    /// Returns the underlying AVAsset for export composition.
    func getAsset() -> AVAsset? {
        asset
    }

    // MARK: - Playback Controls

    func play() {
        player.play()
    }

    func pause() {
        player.pause()
    }

    func seek(to seconds: Double) async {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        await player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func setRate(_ rate: Float) {
        player.rate = rate
    }

    // MARK: - Time Observation

    private func setupTimeObserver() {
        removeTimeObserver()

        // Publish time updates ~30 times per second for smooth UI
        let interval = CMTime(seconds: 1.0 / 30.0, preferredTimescale: 600)
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
}
