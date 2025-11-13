//
//  MetricsView.swift
//  SOOLRA
//
//  Created by Michael Essiet on 02/11/2025.
//

import SwiftUI

// A reusable view for each row of statistics
struct MetricBanner: View {
    let iconName: String
    let title: String
    let value: String

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

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 20))

            Text(title)
                .fontWeight(.bold)

            Spacer()

            Text(value)
                .fontWeight(.semibold)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(height: 37)
        // 1. Use the shape for the background fill
        .background(shape.fill(purpleColor))
        // 2. Use an overlay to add the stroke
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
        // 3. To use it as a clip shape (as requested):
        // .clipShape(shape)
    }
}

// Main view to display the list of metrics
struct PlayerStatsView: View {
    var body: some View {
        ZStack {
            // Background from your previous request
            Color(red: 60 / 255, green: 55 / 255, blue: 90 / 255)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                MetricBanner(
                    iconName: "target",
                    title: "Points Earned",
                    value: "16"
                )

                MetricBanner(
                    iconName: "trophy.fill",
                    title: "Time Played Ranking",
                    value: "89%"
                )

                MetricBanner(
                    iconName: "hourglass",
                    title: "Total Time Played",
                    value: "12 Days"
                )
            }
            .padding()
        }
    }
}

#Preview {
    PlayerStatsView()
}
