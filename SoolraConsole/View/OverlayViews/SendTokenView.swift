//
//  SendTokenView.swift
//  SOOLRA
//
//  Created by Claude on 22/03/2026.
//

import SwiftUI

struct SendTokenView: View {
    @Binding var isPresented: Bool
    @StateObject private var viewModel = SendTokenViewModel()

    var body: some View {
        VStack(spacing: 16) {
            // Header
            Text("Send Tokens")
                .font(.largeTitle)
                .foregroundStyle(.white)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .fontWeight(.semibold)

            switch viewModel.step {
            case .input:
                inputView
            case .confirming:
                confirmView
            case .sending:
                sendingView
            case .success:
                successView
            case .failed:
                failedView
            }

            Spacer()
        }
        .purpleGradientBackground()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
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
    }

    // MARK: - Input Step

    private var inputView: some View {
        VStack(spacing: 20) {
            // Token Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Token")
                    .foregroundStyle(.white.opacity(0.7))
                    .font(.subheadline)

                HStack(spacing: 0) {
                    ForEach(viewModel.tokens, id: \.self) { token in
                        Button {
                            withAnimation { viewModel.selectedToken = token }
                        } label: {
                            Text(token)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    viewModel.selectedToken == token
                                        ? Color.purple : Color.white.opacity(0.1)
                                )
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal)

            // Amount
            VStack(alignment: .leading, spacing: 8) {
                Text("Amount")
                    .foregroundStyle(.white.opacity(0.7))
                    .font(.subheadline)

                TextField("0.00", text: $viewModel.amount)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .padding()
                    .foregroundStyle(.white)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal)

            // To Address
            VStack(alignment: .leading, spacing: 8) {
                Text("Recipient Address")
                    .foregroundStyle(.white.opacity(0.7))
                    .font(.subheadline)

                TextField("0x...", text: $viewModel.toAddress)
                    .keyboardType(.asciiCapable)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .textFieldStyle(.plain)
                    .padding()
                    .foregroundStyle(.white)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal)

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }

            // Continue Button
            Button {
                Task { await viewModel.getPayload() }
            } label: {
                AngledBanner {
                    Text("Continue")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
            }
            .disabled(!viewModel.isInputValid)
            .opacity(viewModel.isInputValid ? 1.0 : 0.5)
            .padding(.horizontal)
        }
    }

    // MARK: - Confirm Step

    private var confirmView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                confirmRow(label: "Token", value: viewModel.selectedToken)
                confirmRow(label: "Amount", value: viewModel.amount)
                confirmRow(
                    label: "To",
                    value: truncatedAddress(viewModel.toAddress)
                )
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }

            // Confirm Button
            Button {
                Task { await viewModel.confirmAndSend() }
            } label: {
                AngledBanner {
                    Text("Confirm & Send")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)

            // Back Button
            Button {
                withAnimation { viewModel.step = .input }
            } label: {
                Text("Go Back")
                    .foregroundStyle(.white.opacity(0.7))
                    .font(.subheadline)
            }
        }
    }

    // MARK: - Sending Step

    private var sendingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.5)

            Text("Sending \(viewModel.amount) \(viewModel.selectedToken)...")
                .foregroundStyle(.white)
                .font(.headline)

            Text("Please wait, this may take a moment.")
                .foregroundStyle(.white.opacity(0.7))
                .font(.subheadline)
        }
        .padding()
    }

    // MARK: - Success Step

    private var successView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("Transfer Successful")
                .foregroundStyle(.white)
                .font(.headline)

            if let hash = viewModel.transactionHash {
                Text("Tx: \(truncatedAddress(hash))")
                    .foregroundStyle(.white.opacity(0.7))
                    .font(.caption)
            }

            Button {
                viewModel.reset()
            } label: {
                AngledBanner {
                    Text("Send Another")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)

            Button {
                withAnimation { isPresented = false }
            } label: {
                Text("Done")
                    .foregroundStyle(.white.opacity(0.7))
                    .font(.subheadline)
            }
        }
        .padding()
    }

    // MARK: - Failed Step

    private var failedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)

            Text("Transfer Failed")
                .foregroundStyle(.white)
                .font(.headline)

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.white.opacity(0.7))
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }

            Button {
                withAnimation { viewModel.step = .input }
            } label: {
                AngledBanner {
                    Text("Try Again")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
        }
        .padding()
    }

    // MARK: - Helpers

    private func confirmRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(value)
                .foregroundStyle(.white)
                .fontWeight(.semibold)
        }
    }

    private func truncatedAddress(_ address: String) -> String {
        guard address.count > 12 else { return address }
        let prefix = address.prefix(6)
        let suffix = address.suffix(4)
        return "\(prefix)...\(suffix)"
    }
}

#Preview {
    SendTokenView(isPresented: .constant(true))
}
