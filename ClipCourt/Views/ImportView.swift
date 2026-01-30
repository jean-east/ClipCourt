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
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // App Icon / Branding
                VStack(spacing: 16) {
                    Image(systemName: "film.stack")
                        .font(.system(size: 72))
                        .foregroundStyle(.accent)

                    Text("ClipCourt")
                        .font(.largeTitle.bold())

                    Text("Watch once. Keep the best parts.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Import Button
                VStack(spacing: 16) {
                    PhotosPicker(
                        selection: $selectedItem,
                        matching: .videos,
                        photoLibrary: .shared()
                    ) {
                        Label("Choose Video", systemImage: "video.badge.plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isProcessing)

                    if isProcessing {
                        ProgressView("Loading video…")
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    await handleSelection(newItem)
                }
            }
        }
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

            // The itemIdentifier from PhotosPicker is the PHAsset localIdentifier
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
