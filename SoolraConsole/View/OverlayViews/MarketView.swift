//
//  MarketView.swift
//  SOOLRA
//
//  Created by Michael Essiet on 30/10/2025.
//
import SwiftUI

struct MarketView: View {
    @Binding var isPresented: Bool
    @State private var selectedTab: Int = 0

    var body: some View {
        VStack(spacing: 16) {
            Text("Soolra Market").padding().foregroundStyle(.white).font(
                .title2
            ).fontWeight(.bold)

            VStack(spacing: 16) {
                HStack {
                    Text("SOOL BALANCE")
                    Spacer()
                    Text("0.0")
                }
                .padding(.horizontal)
                .frame(maxWidth: 400)
                .fontWeight(.semibold)
                .foregroundStyle(.white)

                HStack(spacing: 0) {
                    Button("PFP") {
                        withAnimation {
                            selectedTab = 0
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 7)
                    .foregroundStyle(
                        selectedTab == 0 ? Color.white : Color.black
                    )
                    .background(selectedTab == 0 ? Color.purple : Color.clear)
                    Button("BANNER") {
                        withAnimation {
                            selectedTab = 1
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 7)
                    .foregroundStyle(
                        selectedTab == 1 ? Color.white : Color.black
                    )
                    .background(selectedTab == 1 ? Color.purple : Color.clear)
                }
                .clipShape(AngledBannerShape())
                .gradientBorder(
                    AngledBannerShape(),
                    colors: [
                        Color(hex: "#FF00E1"),
                        Color(hex: "#FCC4FF"),
                    ]
                )
                .zIndex(1)

                Group {
                    if selectedTab == 0 {
                        ImageGridView()
                    } else {
                        ImageGridView()
                    }
                }

                AngledBanner {
                    // TODO: Implement
                    Button("Get SOOL") {}
                        .frame(maxWidth: 400)
                        .disabled(true)
                }
                .padding()
            }.comingSoon()

            Button("Close") { withAnimation { isPresented.toggle() } }
                .padding()
                .tint(.white)

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
