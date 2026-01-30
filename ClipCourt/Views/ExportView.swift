// ExportView.swift
// ClipCourt
//
// Export configuration sheet: choose quality mode, see progress, done!
// "The rat symbolizes obviousness!" — and this UI symbolizes SIMPLICITY.

import SwiftUI

struct ExportView: View {

    // MARK: - Environment

    @Environment(PlayerViewModel.self) private var playerViewModel
    @Environment(ExportViewModel.self) private var exportViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        @Bindable var vm = exportViewModel

        NavigationStack {
            VStack(spacing: 24) {
                switch exportViewModel.state {
                case .idle:
                    idleContent
                case .exporting:
                    exportingContent
                case .completed:
                    completedContent
                case .failed(let message):
                    failedContent(message: message)
                }
            }
            .padding()
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if exportViewModel.isExporting {
                            exportViewModel.cancelExport()
                        }
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled(exportViewModel.isExporting)
    }

    // MARK: - Idle State

    private var idleContent: some View {
        VStack(spacing: 20) {
            // Summary
            if let project = playerViewModel.project {
                VStack(spacing: 4) {
                    Text("Selected: \(TimeFormatter.format(project.includedDuration))")
                        .font(.headline)
                    Text("\(project.includedSegments.count) segment(s)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Mode picker
            VStack(alignment: .leading, spacing: 12) {
                Text("Export Quality")
                    .font(.headline)

                ForEach(ExportSettings.ExportMode.allCases) { mode in
                    Button {
                        exportViewModel.settings.mode = mode
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(mode.displayName)
                                    .font(.body.bold())
                                Text(mode.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if exportViewModel.settings.mode == mode {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.accent)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(exportViewModel.settings.mode == mode
                                      ? Color.accentColor.opacity(0.1)
                                      : Color(.secondarySystemBackground))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            // Export button
            Button {
                let asset = playerViewModel.playerService.getAsset()
                exportViewModel.startExport(
                    asset: asset,
                    segments: playerViewModel.segments
                )
            } label: {
                Label("Export Video", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Exporting State

    private var exportingContent: some View {
        VStack(spacing: 20) {
            Spacer()

            ProgressView(value: exportViewModel.progress) {
                Text("Exporting…")
                    .font(.headline)
            } currentValueLabel: {
                Text("\(Int(exportViewModel.progress * 100))%")
                    .monospacedDigit()
            }

            Text(exportViewModel.settings.mode == .lossless
                 ? "Remuxing at original quality"
                 : "Re-encoding video")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Cancel Export", role: .destructive) {
                exportViewModel.cancelExport()
            }
        }
    }

    // MARK: - Completed State

    private var completedContent: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("Export Complete!")
                .font(.title2.bold())

            Text("Video saved to your photo library")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Done") {
                exportViewModel.reset()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Failed State

    private func failedContent(message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.red)

            Text("Export Failed")
                .font(.title2.bold())

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            HStack(spacing: 16) {
                Button("Dismiss") {
                    exportViewModel.reset()
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Retry") {
                    exportViewModel.reset()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ExportView()
        .environment(PlayerViewModel())
        .environment(ExportViewModel())
}
