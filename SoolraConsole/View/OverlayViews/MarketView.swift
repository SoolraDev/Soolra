//
//  MarketView.swift
//  SOOLRA
//
//  Created by Michael Essiet on 30/10/2025.
//
import SwiftUI

struct MarketView: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 16) {
            Text("Soolra Market").padding().foregroundStyle(.white).font(
                .title2
            ).fontWeight(.bold)

            HStack {
                Text("SOOL BALANCE")
                Spacer()
                Text("0.0")
            }
            .padding(.horizontal)
            .frame(maxWidth: 400)
            .fontWeight(.semibold)
            .foregroundStyle(.white)

            Grid {
                GridRow {
                    ForEach(0..<2) { index in
                        AsyncImage(
                            url: URL(
                                string:
                                    "https://random.danielpetrica.com/api/random?format=thumb"
                            )
                        ) { image in
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 165, height: 100)
                                .cornerRadius(10)
                                .gradientBorder(
                                    RoundedRectangle(cornerRadius: 10),
                                    colors: [
                                        Color(hex: "#FF00E1"),
                                        Color(hex: "#FCC4FF"),
                                    ]
                                )
                        } placeholder: {
                            ProgressView()
                        }
                    }
                }
                GridRow {
                    ForEach(0..<2) { index in
                        AsyncImage(
                            url: URL(
                                string:
                                    "https://random.danielpetrica.com/api/random?format=thumb"
                            )
                        ) { image in
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 165, height: 100)
                                .cornerRadius(10)
                                .gradientBorder(
                                    RoundedRectangle(cornerRadius: 10),
                                    colors: [
                                        Color(hex: "#FF00E1"),
                                        Color(hex: "#FCC4FF"),
                                    ]
                                )
                        } placeholder: {
                            ProgressView()
                        }
                    }
                }
                GridRow {
                    ForEach(0..<2) { index in
                        AsyncImage(
                            url: URL(
                                string:
                                    "https://random.danielpetrica.com/api/random?format=thumb"
                            )
                        ) { image in
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 165, height: 100)
                                .cornerRadius(10)
                                .gradientBorder(
                                    RoundedRectangle(cornerRadius: 10),
                                    colors: [
                                        Color(hex: "#FF00E1"),
                                        Color(hex: "#FCC4FF"),
                                    ]
                                )
                        } placeholder: {
                            ProgressView()
                        }
                    }
                }
                GridRow {
                    ForEach(0..<2) { index in
                        AsyncImage(
                            url: URL(
                                string:
                                    "https://random.danielpetrica.com/api/random?format=thumb"
                            )
                        ) { image in
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 165, height: 100)
                                .cornerRadius(10)
                                .gradientBorder(
                                    RoundedRectangle(cornerRadius: 10),
                                    colors: [
                                        Color(hex: "#FF00E1"),
                                        Color(hex: "#FCC4FF"),
                                    ]
                                )
                        } placeholder: {
                            ProgressView()
                        }
                    }
                }
            }

            AngledBanner {
                // TODO: Implement
                Button("Get SOOL") {}
                    .frame(maxWidth: 400)
                    .disabled(true)
            }
            .padding()

        }
        .purpleGradientBackground()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .frame(maxWidth: 400, maxHeight: .infinity)
        .padding()
        .edgesIgnoringSafeArea(.all)
        .background(.gray.opacity(0.5))
    }
}

struct MarketViewModifier: ViewModifier {
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .center) {
                if isPresented {
                    MarketView(isPresented: $isPresented)
                        .overlayBackground(isPresented: $isPresented)
                }
            }
    }
}

struct MarketViewPreview: View {
    @State var isPresented: Bool = true

    var body: some View {
        MarketView(isPresented: $isPresented)
    }
}

#Preview {
    MarketViewPreview()
}

extension View {
    func marketOverlay(isPresented: Binding<Bool>) -> some View {
        modifier(MarketViewModifier(isPresented: isPresented))
    }
}
