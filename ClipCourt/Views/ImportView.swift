// ImportView.swift
// ClipCourt
//
// The entry screen: pick a video from the camera roll.
// "Hi, Super Nintendo Chalmers!" — Hi, PHPickerViewController!

import PhotosUI
import SwiftUI

struct ImportView: View {

    // MARK: - Environment

    @Environment(PlayerViewModel.self) private var viewModel

    // MARK: - State

    @State private var selectedItem: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var errorMessage: String?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Empty state content (Design.md specs)
            VStack(spacing: 16) {
                // Icon (Design.md: video.badge.plus, 56pt, ccTextSecondary)
                Image(systemName: "video.badge.plus")
                    .font(.system(size: 56))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.ccTextSecondary)

                // Headline (Design.md: .title2 Bold, ccTextPrimary)
                Text("Tap to open a video")
                    .font(.title2.bold())
                    .foregroundStyle(Color.ccTextPrimary)

                // Body (Design.md: .body Regular, ccTextSecondary)
                Text("Pick a game film from your camera roll and start clipping")
                    .font(.body)
                    .foregroundStyle(Color.ccTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
                .frame(height: 24)

            // Import Button (Design.md: Signal Blue bg, white label, 52pt, 200pt wide, 16pt radius)
            VStack(spacing: 16) {
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .videos,
                    photoLibrary: .shared()
                ) {
                    Text("Choose Video")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 200, height: 52)
                        .background(Color.ccExport, in: RoundedRectangle(cornerRadius: 16))
                }
                .disabled(isProcessing)

                if isProcessing {
                    ProgressView("Loading video…")
                        .foregroundStyle(Color.ccTextSecondary)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(Color.ccDanger)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }

            Spacer()
        }
        .background(Color.ccBackground)
        .onChange(of: selectedItem) { _, newItem in
            Task {
                await handleSelection(newItem)
            }
        }
        // Make entire empty state tappable (Design.md: forgiving design)
        .contentShape(Rectangle())
    }

    // MARK: - Selection Handling

    private func handleSelection(_ item: PhotosPickerItem?) async {
        guard let item else { return }

        isProcessing = true
        errorMessage = nil

        do {
            // Get the PHAsset identifier from the picker item
            guard let assetIdentifier = item.itemIdentifier else {
                throw ImportError.noIdentifier
            }

            await viewModel.startNewProject(assetIdentifier: assetIdentifier)
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
        selectedItem = nil
    }
}

// MARK: - Errors

enum ImportError: LocalizedError {
    case noIdentifier
    case loadFailed(String)

    var errorDescription: String? {
        switch self {
        case .noIdentifier:
            "Could not identify the selected video."
        case .loadFailed(let reason):
            "Failed to load video: \(reason)"
        }
    }
}

// MARK: - Preview

#Preview {
    ImportView()
        .environment(PlayerViewModel())
}
