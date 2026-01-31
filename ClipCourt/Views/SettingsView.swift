// SettingsView.swift
// ClipCourt
//
// Settings + tips sheet — the single hub for user preferences.
// Opened via the gear button in the export bar.

import SwiftUI

struct SettingsView: View {

    // MARK: - Persisted Settings

    @AppStorage("holdPlaybackSpeed") private var holdPlaybackSpeed: Double = 2.0
    @AppStorage("keepingUIStyle") private var keepingUIStyle: String = "button"
    @AppStorage("scrubWhileKeeping") private var scrubWhileKeeping: String = "pauseOnScrub"

    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                // MARK: How to Use ClipCourt
                Section {
                    tipRow(icon: "video.badge.plus",
                           text: "Tap \"Choose Video\" to pick a game from your camera roll")
                    tipRow(icon: "hand.tap",
                           text: "Tap \"Tap to Keep\" while watching — tap again to stop")
                    tipRow(icon: "checkmark.circle.fill",
                           text: "Green = highlights you're keeping · Dark = parts that get skipped")
                    tipRow(icon: "arrow.up.left.and.arrow.down.right",
                           text: "Scroll the timeline to scrub · Pinch to zoom in for precision")
                    tipRow(icon: "slider.horizontal.3",
                           text: "Drag the seek bar to jump to any point in the video")
                    tipRow(icon: "hand.tap.fill",
                           text: "Long-press a green clip on the timeline to remove it")
                    tipRow(icon: "forward.fill",
                           text: "Long-press the video to fast-forward at your chosen speed")
                    tipRow(icon: "square.and.arrow.up",
                           text: "Tap Export to save your highlight reel to Camera Roll 🏐")
                } header: {
                    Text("How to Use ClipCourt")
                }

                // MARK: Settings
                Section {
                    // Long-press playback speed
                    Picker("Long Press Speed", selection: $holdPlaybackSpeed) {
                        Text("0.25×").tag(0.25)
                        Text("0.5×").tag(0.5)
                        Text("0.75×").tag(0.75)
                        Text("1×").tag(1.0)
                        Text("1.5×").tag(1.5)
                        Text("2×").tag(2.0)
                        Text("3×").tag(3.0)
                        Text("4×").tag(4.0)
                    }

                    // Scrub-while-keeping behavior
                    Picker("Scrub While Keeping", selection: $scrubWhileKeeping) {
                        Text("Pause on Scrub").tag("pauseOnScrub")
                        Text("Keep Playing").tag("keepPlaying")
                    }

                    // Keeping UI style
                    Picker("Keeping Control", selection: $keepingUIStyle) {
                        Text("Button").tag("button")
                        Text("Slider").tag("slider")
                    }
                } header: {
                    Text("Settings")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Helpers

    private func tipRow(icon: String, text: String) -> some View {
        Label {
            Text(text)
                .font(.subheadline)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(Color.ccTextSecondary)
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
