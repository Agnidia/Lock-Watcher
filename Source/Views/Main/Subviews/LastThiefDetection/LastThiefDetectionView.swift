//
//  LastThiefDetectionView.swift
//
//  Created on 30.06.2023.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

/// A SwiftUI View that displays the last detected thief's image and a list of related images.
struct LastThiefDetectionView: View {
    /// The view model that provides data and behavior.
    /// Uses `@State` for @Observable view models that are owned by this view.
    @Environment(LastThiefDetectionViewModel.self) var viewModel

    var body: some View {
        let _ = Self.logViewChanges()
        VStack(alignment: .center, spacing: DesignSystem.Spacing.sm) {
            if let lastImage = viewModel.selectedItem, let image = NSImage(data: lastImage.data) {
                mainImageContent(lastImage: lastImage, image: image)
            } else {
                emptyStateView
            }
        }
    }

    // MARK: - Extracted Views

    /// Main content showing the selected snapshot
    @ViewBuilder
    private func mainImageContent(lastImage: DatabaseDto, image: NSImage) -> some View {
        Text("LastSnapshot")
            .accessibilityIdentifier(AccessibilityID.Main.lastSnapshot)

        mainSnapshotImage(lastImage: lastImage, image: image)

        Text("\(lastImage.date, formatter: Date.defaultFormat)")
            .accessibilityIdentifier(AccessibilityID.Main.snapshotDate)
            .accessibilityLabel(AccessibilityLabel.Main.snapshotDate(lastImage.date.formatted()))

        if viewModel.latestImages.count > 1 {
            imageGallery(selectedImage: lastImage)
        }
    }

    /// The main snapshot image display
    private func mainSnapshotImage(lastImage: DatabaseDto, image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .scaledToFit()
            .cornerRadius(DesignSystem.CornerRadius.md)
            .frame(maxWidth: .infinity, minHeight: DesignSystem.Layout.mainImageHeight, maxHeight: DesignSystem.Layout.mainImageHeight, alignment: .center)
            .onTapGesture {
                guard let filePath = lastImage.path else { return }
                NSWorkspace.shared.open(filePath)
            }
            .accessibilityIdentifier(AccessibilityID.Main.snapshotImage)
            .accessibilityLabel(AccessibilityLabel.Main.lastSnapshot)
            .accessibilityHint(AccessibilityHint.Main.tapToOpen)
            .accessibilityAddTraits(.isImage)
            .accessibilityAddTraits(.isButton)
    }

    /// Horizontal gallery of all snapshots
    private func imageGallery(selectedImage: DatabaseDto) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(Array(viewModel.latestImages.enumerated()), id: \.element.id) { index, imageDto in
                    galleryItem(imageDto: imageDto, index: index, isSelected: selectedImage == imageDto)
                }
            }
        }
        .frame(height: DesignSystem.Layout.galleryHeight, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .stroke(Color.gray, lineWidth: DesignSystem.Layout.borderWidth)
        )
        .accessibilityIdentifier(AccessibilityID.Main.imageGallery)
        .accessibilityLabel(AccessibilityLabel.Main.snapshotGallery)
    }

    /// Individual gallery item
    @ViewBuilder
    private func galleryItem(imageDto: DatabaseDto, index: Int, isSelected: Bool) -> some View {
        if let image = NSImage(data: imageDto.data) {
            ZStack(alignment: .topTrailing) {
                galleryImageWithDate(image: image, imageDto: imageDto, isSelected: isSelected)
                removeButton(imageDto: imageDto)
            }
            .padding()
            .onTapGesture {
                viewModel.selectedItem = imageDto
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(AccessibilityLabel.Main.galleryImage(index + 1, total: viewModel.latestImages.count))
            .accessibilityHint(AccessibilityHint.Main.tapToSelect)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }

    /// Gallery image with date overlay
    private func galleryImageWithDate(image: NSImage, imageDto: DatabaseDto, isSelected: Bool) -> some View {
        ZStack(alignment: .bottom) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .cornerRadius(DesignSystem.CornerRadius.sm)

            Text("\(imageDto.date, formatter: Date.defaultFormat)")
                .font(DesignSystem.Typography.callout)
                .padding(DesignSystem.Spacing.xs)
                .background(isSelected ? DesignSystem.Colors.accent : Color.gray)
                .cornerRadius(DesignSystem.CornerRadius.sm)
        }
    }

    /// Remove button for gallery items
    private func removeButton(imageDto: DatabaseDto) -> some View {
        Button(action: {
            viewModel.remove(imageDto)
        }) {
            Image(systemName: "xmark.square.fill")
                .font(DesignSystem.Typography.body)
                .padding(DesignSystem.Spacing.xs)
                .foregroundColor(DesignSystem.Colors.error)
                .cornerRadius(DesignSystem.CornerRadius.xs)
        }
        .buttonStyle(BorderlessButtonStyle())
        .accessibilityIdentifier(AccessibilityID.Main.removeImageButton)
        .accessibilityLabel(AccessibilityLabel.Main.removeSnapshot)
        .accessibilityHint(AccessibilityHint.Main.tapToRemove)
    }

    /// Empty state when no snapshots available
    private var emptyStateView: some View {
        Text("Nothing to show")
            .font(DesignSystem.Typography.title2)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding()
            .accessibilityIdentifier(AccessibilityID.Main.emptyState)
            .accessibilityLabel(AccessibilityLabel.Main.emptyState)
    }
}

#Preview("Last Thief Detection") {
    LastThiefDetectionView()
        .environment(LastThiefDetectionViewModel(databaseManager: DatabaseManagerPreview()))
}
