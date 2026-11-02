//
//  ExtendedDivider.swift
//
//  Created on 19.05.2022.
//  Copyright © 2026 Agnidia. All rights reserved.
//

import SwiftUI

/// View modifier for creating an extended divider with an associated title.
struct ExtendedDividerModifier: ViewModifier {
    var isExtended: Binding<Bool>

    var titleKey: String = "" // Key for localizing the title text.
    var font: Font = .headline // Font used for the title.
    var lineWidth: CGFloat = DesignSystem.Layout.borderWidth // Width of the divider line.
    var lineColor: Color = .init("divider") // Color of the divider line.

    /// Modifies the provided content by adding an extended divider to it.
    func body(content: Content) -> some View {
        ExtendedDivider(isExtended: isExtended, titleKey: titleKey, font: font, lineWidth: lineWidth, lineColor: lineColor)

        if isExtended.wrappedValue {
            content
                .clipped()
        }
    }
}

extension View {
    /// Attaches the extended divider modifier to the view.
    func extended(_ isExtended: Binding<Bool>, titleKey: String = "", font: Font = .headline, lineWidth: CGFloat = DesignSystem.Layout.borderWidth, lineColor: Color = DesignSystem.Colors.divider) -> some View {
        modifier(ExtendedDividerModifier(isExtended: isExtended, titleKey: titleKey, font: font, lineWidth: lineWidth, lineColor: lineColor))
    }
}

/// Represents a visual divider that can be extended with an associated title.
struct ExtendedDivider: View {
    /// Represents a single line (either horizontal or vertical) used within the extended divider.
    private struct ExtendedDividerLine: View {
        let width: CGFloat
        let color: Color
        var direction: Axis.Set = .horizontal

        var body: some View {
            Rectangle()
                .fill(color)
                .applyIf(direction == .vertical) {
                    $0.frame(width: width)
                        .ignoresSafeArea(.all, edges: .vertical)
                } else: {
                    $0.frame(height: width)
                        .ignoresSafeArea(.all, edges: .horizontal)
                }
        }
    }

    var isExtended: Binding<Bool>

    @State var titleKey = "" // Key for localizing the title text.
    @State var font: Font = .headline // Font used for the title.
    @State var lineWidth: CGFloat = DesignSystem.Layout.borderWidth // Width of the divider line.
    @State var lineColor = DesignSystem.Colors.divider // Color of the divider line.

    @State private var chevronRotation: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var animation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: isExtended.wrappedValue ? 0.2 : 0.01)
    }

    private func toggle() {
        withAnimation(animation) {
            chevronRotation = isExtended.wrappedValue ? 180 : 0
            isExtended.wrappedValue.toggle()
        }
    }

    var body: some View {
        HStack(alignment: .top) {
            ExtendedDividerLine(width: lineWidth, color: lineColor)
            Button(action: toggle) {
                HStack {
                    if !titleKey.isEmpty {
                        Text(NSLocalizedString(titleKey, comment: ""))
                            .font(font)
                    }
                    Image(systemName: "chevron.compact.down")
                        .font(font)
                        .foregroundColor(isExtended.wrappedValue ? DesignSystem.Colors.extendedMenu : DesignSystem.Colors.defaultMenu)
                        .rotationEffect(.degrees(chevronRotation))
                }
            }
            .buttonStyle(BorderlessButtonStyle())
            .accessibilityIdentifier(AccessibilityID.ExtendedDivider.toggleButton)
            .accessibilityLabel(
                isExtended.wrappedValue
                    ? AccessibilityLabel.ExtendedDivider.collapse(titleKey.isEmpty ? "" : NSLocalizedString(titleKey, comment: ""))
                    : AccessibilityLabel.ExtendedDivider.expand(titleKey.isEmpty ? "" : NSLocalizedString(titleKey, comment: ""))
            )
            ExtendedDividerLine(width: lineWidth, color: lineColor)
        }
        .onTapGesture(perform: toggle)
        .padding(DesignSystem.Spacing.xs)
        .accessibilityIdentifier(AccessibilityID.ExtendedDivider.container)
        .accessibilityElement(children: .combine)
        .onAppear {
            chevronRotation = isExtended.wrappedValue ? 0 : 180
        }
    }
}

#Preview("Extended") {
    ExtendedDivider(isExtended: .constant(true))
}

#Preview("Collapsed") {
    ExtendedDivider(isExtended: .constant(false))
}
