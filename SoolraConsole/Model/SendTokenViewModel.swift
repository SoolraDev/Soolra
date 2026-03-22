//
//  SendTokenViewModel.swift
//  SOOLRA
//
//  Created by Claude on 22/03/2026.
//

import Foundation
import PrivySDK

// Helper to open the PrivyUser existential so we can call
// the generic generateAuthorizationSignature method on `any PrivyUser`.
private func signPayload<T: Encodable>(
    user: any PrivyUser,
    payload: PrivySDK.WalletApiPayload<T>
) async throws -> String {
    try await user.generateAuthorizationSignature(payload: payload)
}

enum SendTokenStep {
    case input
    case confirming
    case sending
    case success
    case failed
}

@MainActor
class SendTokenViewModel: ObservableObject {
    @Published var toAddress: String = ""
    @Published var amount: String = ""
    @Published var selectedToken: String = "USDT"
    @Published var step: SendTokenStep = .input
    @Published var errorMessage: String?
    @Published var transactionHash: String?

    let tokens = ["USDT", "USDC", "SOOL"]

    private let apiClient = ApiClient()
    private var cachedPayload: TransferPayloadResponse?

    var isInputValid: Bool {
        let addressValid =
            toAddress.hasPrefix("0x") && toAddress.count == 42
        let amountValid =
            Double(amount) != nil && (Double(amount) ?? 0) > 0
        return addressValid && amountValid
    }

    func getPayload() async {
        guard isInputValid else {
            errorMessage = "Please enter a valid address and amount."
            return
        }

        guard let walletId = walletManager.privyUser?.embeddedEthereumWallets.first?.id else {
            errorMessage = "Wallet not found."
            return
        }

        step = .confirming
        errorMessage = nil

        let payload = await apiClient.getTransferPayload(
            to: toAddress,
            token: selectedToken.lowercased(),
            walletId: walletId,
            amount: amount
        )

        if let payload = payload {
            cachedPayload = payload
        } else {
            errorMessage = "Failed to prepare transfer. Please try again."
            step = .input
        }
    }

    func confirmAndSend() async {
        guard let payload = cachedPayload else {
            errorMessage = "No payload available. Please try again."
            step = .input
            return
        }
        
        guard let walletId = walletManager.privyUser?.embeddedEthereumWallets.first?.id else {
            errorMessage = "Wallet not found."
            return
        }

        step = .sending
        errorMessage = nil

        do {
            // Generate the authorization signature using Privy SDK
            guard let user = await walletManager.privyClient.getUser() else {
                errorMessage = "User not authenticated."
                step = .input
                return
            }

            let signaturePayload: PrivySDK.WalletApiPayload<TransferPayloadBody> = PrivySDK.WalletApiPayload(
                version: payload.version,
                url: payload.url,
                method: payload.method,
                headers: payload.headers,
                body: payload.body
            )

            let authorizationSignature =
                try await signPayload(
                    user: user,
                    payload: signaturePayload
                )

            // Send the transfer with the signature
            let result = await apiClient.sendTransfer(
                walletId: walletId,
                payload: payload,
                signature: authorizationSignature,
            )

            if let result = result {
                transactionHash = result.transactionHash
                step = .success
            } else {
                errorMessage = "Transfer failed. Please try again."
                step = .failed
            }
        } catch {
            errorMessage = "Authorization failed: \(error.localizedDescription)"
            step = .failed
        }
    }

    func reset() {
        toAddress = ""
        amount = ""
        selectedToken = "USDT"
        step = .input
        errorMessage = nil
        transactionHash = nil
        cachedPayload = nil
    }
}
