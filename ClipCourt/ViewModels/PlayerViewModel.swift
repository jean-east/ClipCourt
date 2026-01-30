// PlayerViewModel.swift
// ClipCourt
//
// The brain of the player screen. Orchestrates playback, segment toggling,
// and auto-save. "I heard your dad went into a restaurant and ate everything
// in the restaurant and they had to close the restaurant." — This ViewModel
// consumes ALL the complexity so the Views stay thin.

import AVFoundation
import Combine
import Observation
import Photos
import SwiftUI

// MARK: - Playback Speed

enum PlaybackSpeed: Float, CaseIterable, Identifiable {
    case quarterX = 0.25
    case halfX    = 0.5
    case oneX     = 1.0
    case oneHalfX = 1.5
    case twoX     = 2.0

    var id: Float { rawValue }

    var displayName: String {
        switch self {
        case .quarterX: "0.25×"
        case .halfX:    "0.5×"
        case .oneX:     "1×"
        case .oneHalfX: "1.5×"
        case .twoX:     "2×"
        }
    }
}

// MARK: - ViewModel

@Observable
@MainActor
final class PlayerViewModel {

    // MARK: - Published State

    var hasActiveProject: Bool = false
    var isSelectingNewVideo: Bool = false
    var isPlaying: Bool = false
    var isAtEnd: Bool = false
    var isIncluding: Bool = false
    var keepingStartTime: Double?
    var currentTime: Double = 0
    var duration: Double = 0
    var segments: [Segment] = []
    var playbackSpeed: PlaybackSpeed = .oneX
    var isFastForwarding: Bool = false
    var errorMessage: String?
    var isLoading: Bool = false

    /// Cached: whether any segments are marked as included.
    /// Avoids re-filtering the segments array every render cycle.
    var hasIncludedSegments: Bool = false

    // MARK: - Project

    private(set) var project: Project?

    // MARK: - Services

    let playerService: VideoPlayerService
    private let segmentManager: SegmentManager
    private let persistenceService: PersistenceService

    // MARK: - Private State

    private var cancellables = Set<AnyCancellable>()
    private var saveTask: Task<Void, Never>?
    private var speedBeforeFastForward: PlaybackSpeed = .oneX

    // MARK: - Init

    init(
        playerService: VideoPlayerService = VideoPlayerService(),
        segmentManager: SegmentManager? = nil,
        persistenceService: PersistenceService = PersistenceService()
    ) {
        self.playerService = playerService
        self.segmentManager = segmentManager ?? SegmentManager()
        self.persistenceService = persistenceService

        observePlayerTime()
    }

    // MARK: - Segment Update Helper

    /// Updates the segments array and refreshes the cached `hasIncludedSegments` flag.
    /// Call this instead of assigning `segments` directly.
    private func updateSegments(_ newSegments: [Segment]) {
        segments = newSegments
        hasIncludedSegments = newSegments.contains(where: \.isIncluded)
    }

    // MARK: - Time Observation

    private func observePlayerTime() {
        playerService.currentTimePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] time in
                self?.currentTime = time
            }
            .store(in: &cancellables)

        // Handle end-of-video: reset isPlaying and close any open segment (BUG-001)
        playerService.didPlayToEndPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.handleVideoDidPlayToEnd()
            }
            .store(in: &cancellables)
    }

    /// Called when AVPlayer reaches the end of the video.
    /// Resets playback state and finalizes any open segment.
    private func handleVideoDidPlayToEnd() {
        isPlaying = false
        isAtEnd = true

        // If user was including (toggle ON), close the open segment at video end
        if isIncluding {
            let updated = segmentManager.stopIncluding(at: duration)
            updateSegments(updated)
            isIncluding = false
            keepingStartTime = nil
        }

        // Finalize segments to cap at video duration and remove any zero-duration remnants
        let finalized = segmentManager.finalizeSegments(videoDuration: duration)
        updateSegments(finalized)

        scheduleSave()
    }

    // MARK: - Session Lifecycle

    /// Attempt to resume a previously saved project on app launch.
    func attemptResumeSession() async {
        do {
            if let savedProject = try persistenceService.load() {
                await loadProject(savedProject)
            }
        } catch {
            errorMessage = "Failed to restore session: \(error.localizedDescription)"
        }
    }

    /// Start a new project from a PHAsset identifier.
    func startNewProject(assetIdentifier: String) async {
        isLoading = true
        defer { isLoading = false }

        let newProject = Project(assetIdentifier: assetIdentifier)
        await loadProject(newProject)
    }

    /// Load a project: set up the player and segment state.
    private func loadProject(_ projectToLoad: Project) async {
        do {
            isLoading = true

            try await playerService.loadAsset(identifier: projectToLoad.assetIdentifier)
            duration = playerService.durationSeconds

            // Restore segments
            segmentManager.replaceSegments(projectToLoad.segments)
            updateSegments(segmentManager.segments)

            // Restore playback position
            if projectToLoad.lastPlaybackTime > 0 {
                await playerService.seek(to: projectToLoad.lastPlaybackTime)
            }

            project = projectToLoad
            hasActiveProject = true
            isSelectingNewVideo = false
            isLoading = false

            // Check if we were mid-inclusion
            if let lastSegment = segments.last, lastSegment.isIncluded {
                isIncluding = true
            }
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    /// Close the current project and return to import.
    /// Tears down AVPlayer, observers, and all playback resources.
    func closeProject() {
        playerService.cleanup()
        isPlaying = false
        hasActiveProject = false
        isSelectingNewVideo = false
        project = nil
        updateSegments([])
        isIncluding = false
        currentTime = 0
        duration = 0

        try? persistenceService.delete()
    }

    /// Navigate to import screen without closing the current project.
    /// User can come back via the back button if they don't pick a new video.
    func navigateToImport() {
        playerService.pause()
        isPlaying = false
        isSelectingNewVideo = true
    }

    /// Cancel new video selection and return to the active project.
    func cancelSelectNewVideo() {
        isSelectingNewVideo = false
    }

    // MARK: - Playback Controls

    func togglePlayPause() {
        if isPlaying {
            playerService.pause()
        } else {
            playerService.play()
            playerService.setRate(playbackSpeed.rawValue)
        }
        isPlaying = !isPlaying
    }

    func seek(to time: Double) {
        isAtEnd = false
        Task {
            await playerService.seek(to: time)
            currentTime = time
        }
    }

    /// Restart playback from the beginning.
    /// Defaults to not keeping and playing.
    func restart() {
        isAtEnd = false

        // Stop keeping if active
        if isIncluding {
            let updated = segmentManager.stopIncluding(at: currentTime)
            updateSegments(updated)
            isIncluding = false
            keepingStartTime = nil
        }

        Task {
            await playerService.seek(to: 0)
            currentTime = 0
            playerService.play()
            playerService.setRate(playbackSpeed.rawValue)
            isPlaying = true
        }
    }

    func setPlaybackSpeed(_ speed: PlaybackSpeed) {
        playbackSpeed = speed
        if isPlaying {
            playerService.setRate(speed.rawValue)
        }
    }

    // MARK: - Fast Forward (Hold Gesture)

    func beginFastForward() {
        guard !isFastForwarding else { return }
        isFastForwarding = true
        speedBeforeFastForward = playbackSpeed

        // Read user-configured hold speed (default 2×)
        let storedSpeed = UserDefaults.standard.double(forKey: "holdPlaybackSpeed")
        let holdSpeed = storedSpeed > 0 ? Float(storedSpeed) : 2.0

        // Fast forward — does NOT affect segment toggle state (per spec)
        playerService.setRate(holdSpeed)
        if !isPlaying {
            playerService.play()
            isPlaying = true
        }
    }

    func endFastForward() {
        guard isFastForwarding else { return }
        isFastForwarding = false

        // Restore previous speed
        playerService.setRate(playbackSpeed.rawValue)
    }

    // MARK: - Include/Exclude Toggle

    func toggleInclude() {
        if isIncluding {
            // Stop including
            let updated = segmentManager.stopIncluding(at: currentTime)
            updateSegments(updated)
            isIncluding = false
            keepingStartTime = nil
        } else {
            // Start including
            keepingStartTime = currentTime
            let updated = segmentManager.beginIncluding(at: currentTime, videoDuration: duration)
            updateSegments(updated)
            isIncluding = true
        }

        // Start playback automatically when toggling on
        if isIncluding && !isPlaying {
            togglePlayPause()
        }

        scheduleSave()
    }

    /// Toggle a specific segment's included state (from timeline tap).
    func toggleSegment(_ segment: Segment) {
        let updated = segmentManager.toggleSegment(id: segment.id)
        updateSegments(updated)
        scheduleSave()
    }

    // MARK: - Auto-Save

    /// Debounced save — waits 1 second after last change.
    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self?.saveImmediately()
        }
    }

    /// Immediate save — called on scene phase changes and app termination.
    /// Prepares project data on the main actor, then dispatches JSON encoding
    /// and file I/O to a background thread to avoid blocking the UI.
    func saveImmediately() {
        guard var projectToSave = project else { return }

        projectToSave.segments = segments
        projectToSave.lastPlaybackTime = currentTime
        projectToSave.touch()

        project = projectToSave

        let service = persistenceService
        Task.detached { [weak self] in
            do {
                try service.save(projectToSave)
            } catch {
                await MainActor.run {
                    self?.errorMessage = "Auto-save failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
