//
//  ListNFTViewModel.swift
//  SOOLRA
//
//  Created by Michael Essiet on 30/12/2025.
//
import Foundation

@MainActor
class ListNFTViewModel: ObservableObject {
    @Published var isListing = false
    @Published var priceInput = ""
    @Published var selectedPaymentToken: PaymentToken = .SOOL
    @Published var showSuccessToast = false
    @Published var errorMessage: String?
    
    private let apiClient = ApiClient()
    
    func listNFT(nft: NFTMetadata, onSuccess: @escaping () -> Void) async {
        guard let _ = Double(priceInput) else {
            errorMessage = "Please enter a valid price"
            return
        }
        
        isListing = true
        errorMessage = nil
        
        // the token id is after the # in the nft name
        let tokenId = String(nft.name.split(separator: "#").last ?? "")
        
        let response = await apiClient.listItem(
            nftAddress: "0x05999c4956Ee8432CF1B2312d5F2e3EeC90f97B9", // Your Soolra NFT Address
            tokenId: tokenId,
            priceRaw: priceInput,
            paymentToken: selectedPaymentToken
        )
        
        isListing = false
        
        if response != nil {
            showSuccessToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                onSuccess()
            }
        } else {
            errorMessage = "Listing failed. Please try again or reach out to support."
        }
    }
    
    // Simple BigInt simulation for the example if BigInt package isn't installed
    private func BigInt(_ value: Double) -> Int64 {
        return Int64(value)
    }
}
