//
//  ImageView.swift
//  SOOLRA
//
//  Created by Michael Essiet on 10/11/2025.
//
import SwiftUI

struct ImageGridView: View {
    // This unique ID is added to the URL to ensure
    // each AsyncImage loads a new random image.
    let uniqueId = UUID()

    var body: some View {
        Grid(horizontalSpacing: 15, verticalSpacing: 15) {
            // We can use nested ForEach loops to create the grid dynamically
            ForEach(0..<4) { rowIndex in
                GridRow {
                    ForEach(0..<2) { colIndex in
                        AsyncImage(
                            // Appending a unique query param busts the cache
                            url: URL(string: "https://random.danielpetrica.com/api/random?format=thumb&v=\(uniqueId)-\(rowIndex)-\(colIndex)")
                        ) { image in
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 165, height: 100)
                        .cornerRadius(10)
                        .gradientBorder(
                            RoundedRectangle(cornerRadius: 10),
                            colors: [
                                Color(hex: "#FF00E1"),
                                Color(hex: "#FCC4FF"),
                            ]
                        )
                        // This assumes you have the gradientBorder and Color(hex:) extensions
                        // .gradientBorder(...)
                    }
                }
            }
        }
    }
}
