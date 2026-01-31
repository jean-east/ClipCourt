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
    @State private var showReplaceConfirmation = false
    @State private var pendingItem: PhotosPickerItem?

    // MARK: - Body

    /// True when there's an active project and user navigated here to pick a new video.
    private var canGoBack: Bool {
        viewModel.hasActiveProject && viewModel.isSelectingNewVideo
    }

    var body: some View {
        VStack(spacing: 0) {
            // Back button row — only visible when navigating from an active project
            if canGoBack {
                HStack {
                    Button {
                        viewModel.cancelSelectNewVideo()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.body.weight(.semibold))
                            Text("Back to editing")
                                .font(.body)
                        }
                        .foregroundStyle(Color.ccExport)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }

                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer()

            // Empty state content (Design.md specs)
            VStack(spacing: 16) {
                // Icon (Design.md: video.badge.plus, 56pt, ccTextSecondary)
                Image(systemName: "video.badge.plus")
                    .font(.system(size: 56))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.ccTextSecondary)

                // Headline (Design.md: .title2 Bold, ccTextPrimary)
                Text(canGoBack ? "Choose a new video" : "Tap to open a video")
                    .font(.title2.bold())
                    .foregroundStyle(Color.ccTextPrimary)

                // Body (Design.md: .body Regular, ccTextSecondary)
                Text(canGoBack
                     ? "Pick a new game film, or go back to continue editing."
                     : "Pick a game film from your camera roll and start clipping")
                    .font(.body)
                    .foregroundStyle(Color.ccTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Warning when replacing active project
                if canGoBack {
                    Label(
                        "Choosing a new video will replace your current highlights.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.subheadline)
                    .foregroundStyle(Color.ccDanger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 4)
                }
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
                        .foregroundStyle(Color.ccTextPrimary)
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
        .background(Color.ccBackground.ignoresSafeArea())
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            if canGoBack {
                // Active project exists — confirm before replacing
                pendingItem = newItem
                selectedItem = nil
                showReplaceConfirmation = true
            } else {
                Task {
                    await handleSelection(newItem)
                }
            }
        }
        .alert(
            "Start a new video?",
            isPresented: $showReplaceConfirmation
        ) {
            Button("Keep Editing", role: .cancel) {
                pendingItem = nil
            }
            Button("Start New Video", role: .destructive) {
                guard let item = pendingItem else { return }
                pendingItem = nil
                Task {
                    await handleSelection(item)
                }
            }
        } message: {
            Text("All the highlights you've saved from your current video will be lost. This can't be undone.")
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
