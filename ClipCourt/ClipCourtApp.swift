// ClipCourtApp.swift
// ClipCourt
//
// App entry point — "I'm the principal of the app!"

import SwiftUI

@main
struct ClipCourtApp: App {

    // MARK: - State

    @State private var playerViewModel = PlayerViewModel()
    @State private var exportViewModel = ExportViewModel()
    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(playerViewModel)
                .environment(exportViewModel)
                .onChange(of: scenePhase) { _, newPhase in
                    handleScenePhaseChange(newPhase)
                }
        }
    }

    // MARK: - Lifecycle

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .inactive, .background:
            playerViewModel.saveImmediately()
        case .active:
            break
        @unknown default:
            break
        }
    }
}

// MARK: - Content View (Root Navigation)

struct ContentView: View {
    @Environment(PlayerViewModel.self) private var playerViewModel

    var body: some View {
        Group {
            if playerViewModel.hasActiveProject {
                PlayerView()
            } else {
                ImportView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: playerViewModel.hasActiveProject)
        .task {
            await playerViewModel.attemptResumeSession()
        }
    }
}
