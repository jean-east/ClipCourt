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
                    // Hold-to-fast-forward speed
                    Picker("Hold to Fast Forward", selection: $holdPlaybackSpeed) {
                        Text("1.5×").tag(1.5)
                        Text("2×").tag(2.0)
                        Text("3×").tag(3.0)
                        Text("4×").tag(4.0)
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
