//
//  AngledShape.swift
//  SOOLRA
//
//  Created by Michael Essiet on 02/11/2025.
//
import SwiftUI

public struct AngledBannerShape: Shape {
    /// The width of the chevron notch on the right side.
    var notchWidth: CGFloat = 20

    public func path(in rect: CGRect) -> Path {
        var path = Path()

        // Start at the top-left, inset from the corner
        path.move(to: CGPoint(x: notchWidth, y: 0))
        
        // Top edge
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        
        // Right chevron point
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY/1.3))
        
        // Bottom-right corner
        path.addLine(to: CGPoint(x: rect.width - notchWidth, y: rect.height))
        
        // Bottom edge
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        
        // Left angled point
        path.addLine(to: CGPoint(x: 0, y: rect.midY*1.3))

        // Close the path to connect back to the start
        path.closeSubpath()

        return path
    }
}

#Preview("AngledBannerShape") {
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
}
