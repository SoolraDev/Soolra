//
//  AngledShape.swift
//  SOOLRA
//
//  Created by Michael Essiet on 02/11/2025.
//
import SwiftUI

public struct AngledBannerShape: InsettableShape {
    /// The width of the chevron notch on the right side.
    var notchWidth: CGFloat = 20
    var insetAmount: CGFloat = 0

    public func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        var path = Path()

        // Start at the top-left, inset from the corner
        path.move(to: CGPoint(x: notchWidth, y: 0))

        // Top edge
        path.addLine(to: CGPoint(x: rect.width, y: 0))

        // Right chevron point
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY / 1.3))

        // Bottom-right corner
        path.addLine(to: CGPoint(x: rect.width - notchWidth, y: rect.height))

        // Bottom edge
        path.addLine(to: CGPoint(x: 0, y: rect.height))

        // Left angled point
        path.addLine(to: CGPoint(x: 0, y: rect.midY * 1.3))

        // Close the path to connect back to the start
        path.closeSubpath()

        return path
    }

    public func inset(by amount: CGFloat) -> AngledBannerShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}

public struct AngledBanner<Content: View>: View {
    // By using `<Content: View>`, this component can accept
    // any view as its content.
    let content: Content

    // An initializer with `@ViewBuilder` lets you pass in
    // views using a clean, declarative trailing closure syntax.
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    private let shape = AngledBannerShape()
    private let purpleColor = Color(
        red: 115 / 255,
        green: 90 / 255,
        blue: 184 / 255
    )
    private let pinkGlowColor = Color(
        red: 236 / 255,
        green: 93 / 255,
        blue: 204 / 255
    )

    public var body: some View {
        content
            .foregroundColor(.white)
            .padding(.horizontal, 32)  // Increased padding for the angle
            .padding(.vertical, 16)
            .frame(height: 37)
            .background(shape.fill(purpleColor))
            .overlay(
                ZStack {
                    // Soft outer glow using a stroked shape blurred via shadow
                    shape
                        .stroke(pinkGlowColor.opacity(0.6), lineWidth: 2)
                        .shadow(color: pinkGlowColor.opacity(0.5), radius: 4)
                    // Crisp inner stroke for definition
                    shape
                        .stroke(pinkGlowColor, lineWidth: 1)
                }
            )
    }
}
#Preview("AngledBannerShape") {
    VStack {
        ZStack {
            Color.gray.opacity(0.2).ignoresSafeArea()
            AngledBannerShape(notchWidth: 20)
                .fill(.red)
                .frame(width: 180, height: 40)
                .overlay(
                    Text("hello")
                        .font(.headline)
                        .foregroundStyle(.white)
                )
        }
        
        AngledBanner {
            Text("hello")
        }
    }
}

