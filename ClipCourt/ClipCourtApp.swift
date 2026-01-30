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

    // MARK: - Init

    init() {
        // Set window background to ccBackground so no white/default color
        // bleeds through behind safe area insets (status bar, home indicator).
        let bg = UIColor(red: 10/255, green: 10/255, blue: 15/255, alpha: 1) // #0A0A0F Midnight
        UIWindow.appearance().backgroundColor = bg
    }

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
            if playerViewModel.hasActiveProject && !playerViewModel.isSelectingNewVideo {
                PlayerView()
            } else {
                ImportView()
            }
        }
        .background(Color.ccBackground.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.3), value: playerViewModel.hasActiveProject)
        .animation(.easeInOut(duration: 0.3), value: playerViewModel.isSelectingNewVideo)
        .task {
            await playerViewModel.attemptResumeSession()
        }
    }
}
