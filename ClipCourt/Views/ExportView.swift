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
            .navigationTitle("Export Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !exportViewModel.isExporting {
                        Button("Cancel") {
                            dismiss()
                        }
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
            // Summary (Design.md: segment count + total duration)
            if let project = playerViewModel.project {
                VStack(spacing: 4) {
                    Text("\(project.includedSegmentCount) segment\(project.includedSegmentCount == 1 ? "" : "s") · \(TimeFormatter.format(project.includedDuration)) total duration")
                        .font(.body)
                        .foregroundStyle(Color.ccTextSecondary)
                }
            }

            // Mode picker — Design.md option cards
            VStack(spacing: 12) {
                ForEach(ExportSettings.ExportMode.allCases) { mode in
                    exportOptionCard(mode: mode)
                }
            }

            Spacer()

            // Export Now button (Design.md: Signal Blue, 52pt, full width, 16pt radius)
            Button {
                HapticManager.exportTap()
                let asset = playerViewModel.playerService.getAsset()
                exportViewModel.startExport(
                    asset: asset,
                    segments: playerViewModel.segments
                )
            } label: {
                Text("Export Now")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.ccTextPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.ccExport, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - Export Option Card (Design.md)

    private func exportOptionCard(mode: ExportSettings.ExportMode) -> some View {
        let isSelected = exportViewModel.settings.mode == mode

        return Button {
            HapticManager.selection()
            exportViewModel.settings.mode = mode
        } label: {
            HStack(spacing: 12) {
                Image(systemName: mode.iconName)
                    .font(.title3)
                    .foregroundStyle(
                        mode == .lossless ? Color.ccSpeed : Color.ccExport
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.displayName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.ccTextPrimary)

                    Text(mode == .lossless
                         ? "No re-encoding · Fastest\nSame file size as source"
                         : "Re-encoded · Slower export\n~60% of original size")
                        .font(.caption)
                        .foregroundStyle(Color.ccTextSecondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.ccExport.opacity(0.1) : Color.ccSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        isSelected ? Color.ccExport : Color.ccExclude,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Exporting State

    private var exportingContent: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("Exporting…")
                .font(.title2.bold())
                .foregroundStyle(Color.ccTextPrimary)

            // Progress bar (Design.md: 8pt tall, 4pt radius, Signal Blue fill)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.ccSurface)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.ccExport)
                        .frame(width: geometry.size.width * exportViewModel.progress, height: 8)
                        .animation(.linear, value: exportViewModel.progress)
                }
            }
            .frame(height: 8)
            .padding(.horizontal, 32)

            Text("\(Int(exportViewModel.progress * 100))%")
                .font(.body)
                .monospacedDigit()
                .foregroundStyle(Color.ccTextSecondary)

            Spacer()

            // Cancel button (Design.md: Court Red text)
            Button("Cancel Export") {
                exportViewModel.cancelExport()
            }
            .foregroundStyle(Color.ccDanger)
        }
    }

    // MARK: - Completed State

    private var completedContent: some View {
        VStack(spacing: 20) {
            Spacer()

            // Checkmark (Design.md: 56pt, Rally Green, spring bounce)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.ccInclude)
                .symbolEffect(.bounce, value: exportViewModel.state)

            Text("Saved to Camera Roll")
                .font(.title2.bold())
                .foregroundStyle(Color.ccTextPrimary)

            if let project = playerViewModel.project {
                Text("\(TimeFormatter.format(project.includedDuration)) of highlights from \(TimeFormatter.format(playerViewModel.duration)) of footage")
                    .font(.body)
                    .foregroundStyle(Color.ccTextSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Done button (Design.md: Rally Green bg, white label)
            Button {
                HapticManager.exportComplete()
                exportViewModel.reset()
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.ccTextPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.ccInclude, in: RoundedRectangle(cornerRadius: 16))
            }

            // Share button (Design.md: text-only, Signal Blue)
            if let shareURL = exportViewModel.exportedFileURL {
                ShareLink(item: shareURL) {
                    Text("Share Video")
                        .foregroundStyle(Color.ccExport)
                }
            }
        }
    }

    // MARK: - Failed State

    private func failedContent(message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.ccDanger)

            Text("Export Failed")
                .font(.title2.bold())
                .foregroundStyle(Color.ccTextPrimary)

            Text(message)
                .font(.body)
                .foregroundStyle(Color.ccTextSecondary)
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
