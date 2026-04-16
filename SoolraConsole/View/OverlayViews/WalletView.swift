//
//  WalletView.swift
//  SOOLRA
//
//  Created by Michael Essiet on 30/10/2025.
//
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

struct WalletView: View {
    @Binding var isPresented: Bool
    @StateObject var walletmanager = walletManager
    //    @State var usdcBalance: String = "0.00"
    //    @State var usdtBalance: String = "0.00"
    //    @State var soolBalance: String = "0.00"
    @State private var notificationsEnabled: Bool = false
    @State private var isWebviewPresented: Bool = false
    @State private var isSendTokenPresented: Bool = false
    @State private var overlaystate = overlayState
    @State private var isQRCodePresented: Bool = false

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

            HStack {
                Text("SOOL").foregroundStyle(.white).fontWeight(.semibold)
                Spacer()
                AngledBanner {
                    Text(walletmanager.balances["sool"] ?? "0.0")
                }
            }
            .padding(.horizontal)
            .frame(maxWidth: 400)

            Button {
                isSendTokenPresented = true
            } label: {
                AngledBanner {
                    Text("Send Tokens")
                        .frame(maxWidth: 400)
                }
            }
            .padding(.horizontal)

            Button {
                isQRCodePresented = true
            } label: {
                AngledBanner {
                    Text("Receive")
                        .frame(maxWidth: 400)
                }
            }
            .padding(.horizontal)

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

            // NOTE: Previous "Close" button was removed from here
            Spacer().frame(height: 20)
        }
        .purpleGradientBackground()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        // MARK: Close Button Overlay
        .overlay(alignment: .topTrailing) {
            Button {
                withAnimation { isPresented.toggle() }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .padding()
                    .shadow(radius: 2)
            }
        }
        .frame(maxWidth: 400, maxHeight: .infinity)
        .padding()
        .edgesIgnoringSafeArea(.all)
        .background(.gray.opacity(0.5))
        .task {
            await walletmanager.getBalances()
        }
        .fullScreenCover(isPresented: $isSendTokenPresented) {
            SendTokenView(isPresented: $isSendTokenPresented)
        }
        .sheet(isPresented: $isQRCodePresented) {
            WalletQRCodeView(
                address: walletmanager.getAddress() ?? "",
                isPresented: $isQRCodePresented
            )
        }
    }
}

struct WalletQRCodeView: View {
    let address: String
    @Binding var isPresented: Bool
    @State private var copied = false

    var body: some View {
        VStack(spacing: 24) {
            Text("Receive Tokens")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .padding(.top)

            if let qrImage = generateQRCode(from: address) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .background(Color.white)
                    .cornerRadius(12)
            }

            Text("Scan this QR code to send tokens to this wallet")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                UIPasteboard.general.string = address
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    copied = false
                }
            } label: {
                HStack {
                    Text(address)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                }
                .font(.caption)
                .foregroundStyle(.white)
                .padding()
                .frame(maxWidth: 300)
                .background(Color.white.opacity(0.15))
                .cornerRadius(10)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#1a1a2e").ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding()
            }
        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        guard let data = string.data(using: .ascii),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }
        let scale = 200 / outputImage.extent.size.width
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
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
