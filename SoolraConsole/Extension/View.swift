//
//  View.swift
//  SOOLRA
//
//  Created by Michael Essiet on 04/11/2025.
//

import SwiftUI

extension View {
    /// Clips the view to an insettable shape and applies a gradient border inside the clipped bounds.
    ///
    /// By combining clipping and bordering into one modifier, it ensures the border perfectly
    /// matches the shape of the view without needing to pass a separate corner radius.
    ///
    /// - Parameters:
    ///   - shape: The `InsettableShape` to use for both clipping and the border.
    ///   - colors: An array of `Color` to use for the gradient.
    ///   - width: The width of the border. Defaults to 2.
    ///   - startPoint: The start point of the gradient. Defaults to `.topLeading`.
    ///   - endPoint: The end point of the gradient. Defaults to `.bottomTrailing`.
    /// - Returns: A view with the clipping and gradient border applied.
    public func gradientBorder<S: InsettableShape>(
        _ shape: S,
        colors: [Color],
        width: CGFloat = 2,
        startPoint: UnitPoint = .topLeading,
        endPoint: UnitPoint = .bottomTrailing
    ) -> some View {
        self
            // First, clip the view content to the desired shape
            .clipShape(shape)
            // Then, add the gradient border as an overlay
            .overlay(
                // 'strokeBorder' draws the border inside the shape's bounds
                shape.strokeBorder(
                    LinearGradient(
                        gradient: Gradient(colors: colors),
                        startPoint: startPoint,
                        endPoint: endPoint
                    ),
                    lineWidth: width
                )
            )
    }
}

/// A view modifier that applies a blur and an overlay to indicate a "Coming Soon" feature.
struct ComingSoonModifier: ViewModifier {
    /// A boolean to control whether the overlay is active.
    var isEnabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content
                .blur(radius: 8)
                .overlay(
                    ZStack {
                        // Frosted glass effect for a modern iOS look
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .frame(maxWidth: 200, maxHeight: 120)

                        VStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                                .font(.title)
                            Text("Coming Soon")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                        .foregroundStyle(.secondary)
                    }
                )
                // Disable user interaction with the content behind the overlay
                .allowsHitTesting(false)
        } else {
            content
        }
    }
}

/// Extension to make the modifier easier to use.
extension View {
    /// Applies a "Coming Soon" overlay to the view.
    /// - Parameter isEnabled: A boolean to control whether the overlay is visible.
    ///   Defaults to `true`.
    func comingSoon(_ isEnabled: Bool = true) -> some View {
        self.modifier(ComingSoonModifier(isEnabled: isEnabled))
    }
}
