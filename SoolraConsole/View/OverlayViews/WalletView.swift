//
//  WalletView.swift
//  SOOLRA
//
//  Created by Michael Essiet on 30/10/2025.
//
import SwiftUI

struct WalletView: View {
    @Binding var isPresented: Bool
    @StateObject var walletmanager = walletManager
    //    @State var usdcBalance: String = "0.00"
    //    @State var usdtBalance: String = "0.00"
    @State var soolBalance: String = "0.00"
    @State private var notificationsEnabled: Bool = false
    @State private var isWebviewPresented: Bool = false
    @State private var overlaystate = overlayState

    var body: some View {
        VStack(spacing: 16) {
            Text("Balances")
                .font(.largeTitle)
                .foregroundStyle(.white)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .fontWeight(.semibold)

            HStack {
                Text("USDT").foregroundStyle(.white).fontWeight(.semibold)
                Spacer()
                AngledBanner {
                    Text(walletmanager.balances["usdt"] ?? "0.0")
                }
            }
            .padding(.horizontal)
            .frame(maxWidth: 400)

            HStack {
                Text("USDC").foregroundStyle(.white).fontWeight(.semibold)
                Spacer()
                AngledBanner {
                    Text(walletmanager.balances["usdc"] ?? "0.0")
                }
            }
            .padding(.horizontal)
            .frame(maxWidth: 400)

            //            HStack {
            //                Text("SOOL").foregroundStyle(.white).fontWeight(.semibold)
            //                Spacer()
            //                AngledBanner {
            //                    Text(soolBalance)
            //                }
            //            }
            //            .padding(.horizontal)
            //            .frame(maxWidth: 400)

            AngledBanner {
                // TODO: Implement
                Button("Get SOOL") {}
                    .frame(maxWidth: 400)
                    .disabled(true)
            }
            .padding()

            VStack {
                Menu {
                    Toggle("Enable notifications", isOn: $notificationsEnabled)
                        .padding()
                        .disabled(true)

                    Menu {
                        Text("Placeholder")
                    } label: {
                        Text("Language settings").fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding()
                    }
                    .menuStyle(.automatic)

                    HStack {
                        Link(
                            "Privacy policy",
                            destination: URL(
                                string:
                                    "https://shop.soolra.com/policies/privacy-policy"
                            )!
                        )
                    }

                } label: {
                    HStack {
                        Image(systemName: "gear")
                        Text("General settings").fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "chevron.down")
                    }
                    .foregroundStyle(.white)
                    .padding()
                }
                .menuStyle(.automatic)
                .menuOrder(.fixed)
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            Button("Close") {
                overlaystate.isWalletOverlayVisible.wrappedValue = false
            }.padding().foregroundStyle(.white)
        }
        .purpleGradientBackground()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .frame(maxWidth: 400, maxHeight: .infinity)
        .padding()
        .edgesIgnoringSafeArea(.all)
        .background(.gray.opacity(0.5))
        .task {
            await walletmanager.getBalances()
        }
    }
}

struct WalletViewModifier: ViewModifier {
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .center) {
                if isPresented {
                    WalletView(isPresented: $isPresented)
                        .overlayBackground(isPresented: $isPresented)
                }
            }
    }
}

struct WalletPreview: View {
    @State var isPresented = true

    var body: some View {
        WalletView(isPresented: $isPresented)
    }
}

#Preview {
    WalletPreview()
}

extension View {
    func walletOverlay(isPresented: Binding<Bool>) -> some View {
        modifier(WalletViewModifier(isPresented: isPresented))
    }
}
