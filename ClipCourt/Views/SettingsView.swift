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
                // MARK: Timeline Tips
                Section {
                    tipRow(icon: "hand.tap", text: "Tap to Keep marks highlights as you watch")
                    tipRow(icon: "timeline.selection", text: "Tap timeline to seek")
                    tipRow(icon: "hand.tap.fill", text: "Long-press clip to remove/restore")
                    tipRow(icon: "arrow.up.left.and.arrow.down.right", text: "Pinch to zoom, drag to scroll")
                } header: {
                    Text("Timeline Tips")
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
