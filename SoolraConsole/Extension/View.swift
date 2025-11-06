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
