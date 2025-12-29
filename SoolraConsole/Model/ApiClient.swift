//
//  ApiClient.swift
//  SOOLRA
//
//  Created by Michael Essiet on 17/11/2025.
//

import Foundation

// A simple singleton to hold the user's authentication credentials.
// This is populated by WalletManager and used by ApiClient.
class AuthManager {
    static let shared = AuthManager()

    var currentPrivyId: String?
    var currentJwt: String?

    private init() {}

    func getAuthHeaders() -> [String: String]? {
        guard let privyId = currentPrivyId, let jwt = currentJwt else {
            print(
                "⚠️ AuthManager: Cannot create auth headers, user credentials not set."
            )
            return nil
        }

        return [
            "Content-Type": "application/json",
            "jwt": jwt,
            "authorization": "Bearer \(jwt)",
        ]
    }

    func clear() {
        currentPrivyId = nil
        currentJwt = nil
    }
}

class ApiClient {
    private let baseURL = URL(string: Configuration.soolraBackendURL)!

    // MARK: - User Metrics & Game Sessions

    // Fetches the user's metrics from the backend
    func fetchUserMetrics(userId: String) async -> UserMetricsResponse? {
        guard let headers = AuthManager.shared.getAuthHeaders() else {
            return nil
        }
        let url = baseURL.appendingPathComponent("/v1/users/\(userId)/metrics")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers

        do {
            let (data, response) = try await URLSession.shared.data(
                for: request
            )
            guard let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200
            else {
                print("🚨 Fetch metrics failed")
                return nil
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(UserMetricsResponse.self, from: data)
        } catch {
            print("🚨 Error fetching metrics: \(error)")
            return nil
        }
    }

    // Uploads a single game session
    func postGameSession(_ session: GameSessionRecord, userId: String) async
        -> Bool
    {
        guard let headers = AuthManager.shared.getAuthHeaders() else {
            return false
        }
        let url = baseURL.appendingPathComponent("/v1/users/\(userId)/metrics")

        let payload = MetricsUploadBody.GameSessionPayload(
            gameName: session.gameName,
            score: session.score,
            duration: Int(session.duration * 1000)
        )
        let body = MetricsUploadBody(gameSession: payload)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers

        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 204
            else {
                return false
            }
            return true
        } catch {
            print("🚨 Error posting session: \(error)")
            return false
        }
    }

    // MARK: - User NFTs

    // Fetches the user's NFTs from the backend
    func fetchUserNFTs(userId: String) async -> [NFTMetadata]? {
        guard let headers = AuthManager.shared.getAuthHeaders() else {
            return nil
        }

        let url = baseURL.appendingPathComponent("/v1/users/\(userId)/nfts")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers

        do {
            let (data, response) = try await URLSession.shared.data(
                for: request
            )
            guard let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200
            else {
                return nil
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([NFTMetadata].self, from: data)
        } catch {
            print("🚨 Error fetching NFTs: \(error)")
            return nil
        }
    }

    // MARK: - Marketplace Read (Listings)

    func fetchMarketplaceListings(offset: Int = 0, limit: Int = 50) async
        -> [MarketplaceListing]?
    {
        // Headers optional for public read, but good to have if you enforce Auth
        let headers = AuthManager.shared.getAuthHeaders()

        guard var components = URLComponents(string: baseURL.absoluteString)
        else { return nil }
        components.path += "/v1/marketplace/listings"
        components.queryItems = [
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "limit", value: String(limit)),
        ]

        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers

        do {
            let (data, response) = try await URLSession.shared.data(
                for: request
            )
            guard let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200
            else {
                return nil
            }
            let decoder = JSONDecoder()
            return try decoder.decode([MarketplaceListing].self, from: data)
        } catch {
            print("🚨 Error fetching marketplace listings: \(error)")
            return nil
        }
    }

    func fetchListingDetails(id: String) async -> MarketplaceListing? {
        let headers = AuthManager.shared.getAuthHeaders()
        let url = baseURL.appendingPathComponent(
            "/v1/marketplace/listings/\(id)"
        )

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers

        do {
            let (data, response) = try await URLSession.shared.data(
                for: request
            )
            guard let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200
            else {
                return nil
            }
            let decoder = JSONDecoder()
            return try decoder.decode(MarketplaceListing.self, from: data)
        } catch {
            print("🚨 Error fetching listing details: \(error)")
            return nil
        }
    }

    // MARK: - Marketplace Write (Actions)
    
    /// Lists an item on the marketplace.
    /// The backend handles checking/executing approvals and the listing transaction via the user's embedded wallet.
    /// - Parameters:
    ///   - nftAddress: The contract address of the NFT.
    ///   - tokenId: The ID of the token.
    ///   - priceRaw: The price in atomic units (Wei) as a String.
    ///   - paymentToken: The payment token enum.
    /// - Returns: The response containing the transaction hash if successful.
    func listItem(
        nftAddress: String,
        tokenId: String,
        priceRaw: String,
        paymentToken: PaymentToken
    ) async -> ListActionResponse? {
        guard let headers = AuthManager.shared.getAuthHeaders() else { return nil }
        let url = baseURL.appendingPathComponent("/v1/marketplace/listings")
        
        // Construct body with the String key for paymentToken (e.g., "SOOL")
        let body = ListActionRequest(
            nftAddress: nftAddress,
            tokenId: tokenId,
            price: priceRaw,
            paymentToken: paymentToken.stringKey
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers
        
        do {
            request.httpBody = try JSONEncoder().encode(body)
            
            // This request might take up to 60s+ because the server waits for blockchain mining
            // You might want to increase the local timeout interval
            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.timeoutIntervalForRequest = 120.0 // 2 minutes
            let session = URLSession(configuration: sessionConfig)
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else { return nil }
            
            if httpResponse.statusCode == 200 {
                return try JSONDecoder().decode(ListActionResponse.self, from: data)
            } else {
                // Parse error message for debugging
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = errorJson["message"] as? String { // Elysia default error field
                    print("❌ Listing Failed: \(message)")
                } else {
                    print("❌ Listing Failed with status: \(httpResponse.statusCode)")
                }
                return nil
            }
        } catch {
            print("🚨 Error listing item: \(error)")
            return nil
        }
    }

    /// Triggers a purchase. Since the backend handles server-side signing for purchase execution,
    /// this returns a transaction hash or success message.
    func purchaseListing(listingId: String) async -> TransactionActionResponse?
    {
        guard let headers = AuthManager.shared.getAuthHeaders() else {
            return nil
        }
        let url = baseURL.appendingPathComponent("/v1/marketplace/purchases")

        let body = ["listingId": listingId]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers

        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, response) = try await URLSession.shared.data(
                for: request
            )

            if let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode >= 400
            {
                return nil
            }

            return try JSONDecoder().decode(
                TransactionActionResponse.self,
                from: data
            )
        } catch {
            print("🚨 Error purchasing listing: \(error)")
            return nil
        }
    }

    /// Triggers a delisting. The backend handles execution.
    func delistItem(listingId: String) async -> TransactionActionResponse? {
        guard let headers = AuthManager.shared.getAuthHeaders() else {
            return nil
        }
        let url = baseURL.appendingPathComponent("/v1/marketplace/delistings")

        let body = ["listingId": listingId]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers

        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, response) = try await URLSession.shared.data(
                for: request
            )

            if let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode >= 400
            {
                return nil
            }

            return try JSONDecoder().decode(
                TransactionActionResponse.self,
                from: data
            )
        } catch {
            print("🚨 Error delisting item: \(error)")
            return nil
        }
    }
}

// MARK: JSON models

struct GameSessionRecord: Codable, Identifiable {
    let id: UUID
    let gameName: String
    let duration: TimeInterval
    let score: Int
    let recordedAt: Date
}

struct MetricsUploadBody: Codable {
    struct GameSessionPayload: Codable {
        let gameName: String
        let score: Int
        let duration: Int
    }
    let gameSession: GameSessionPayload?
}

struct UserMetricsResponse: Codable {
    let id: String
    let totalTimePlayed: Int
    let points: Int
    let lastUpdated: Date
    let ranking: Int?
}

struct Game: Codable {
    let imageUrl: String?
    let gameName: String
    let score: Int
    let duration: TimeInterval
}

// MARK: - NFT Models

struct NFTAttribute: Codable {
    let trait_type: String
    let value: AnyCodable
}

struct NFTMetadata: Codable, Identifiable {
    let tokenId: Int
    let name: String
    let description: String
    let image: String
    let attributes: [NFTAttribute]
    let txHash: String?
    let mintedAt: Date?

    var id: Int { tokenId }
}

// MARK: - Marketplace Models

// Matches the request body expected by your Elysia endpoint
struct ListActionRequest: Codable {
    let nftAddress: String
    let tokenId: String
    let price: String
    let paymentToken: String // Server expects the Key String (e.g., "SOOL", "USDC")
}

// Matches the successful JSON response from the server
struct ListActionResponse: Codable {
    let message: String
    let ownerAddress: String
    let listingTransactionHash: String
}

// Ensure this Enum is available (if not already)
enum PaymentToken: Int, Codable, CaseIterable {
    case SOOL = 0
    case USDC = 1
    case USDT = 2
    
    // Helper to get the String key required by the backend validator
    var stringKey: String {
        switch self {
        case .SOOL: return "SOOL"
        case .USDC: return "USDC"
        case .USDT: return "USDT"
        }
    }
}

struct ListingPrice: Codable {
    let raw: String
    let formatted: String
    let token: String
}

struct MarketplaceListing: Codable, Identifiable {
    let id: String  // Listing ID
    let seller: String
    let nftAddress: String
    let tokenId: String
    let price: ListingPrice
    let paymentToken: PaymentToken
    let active: Bool
    let metadata: NFTMetadata?  // Reusing existing metadata model
}

// MARK: - Transaction & Action Models

struct ListingRequest: Codable {
    let nftAddress: String
    let tokenId: String
    let price: String
    let paymentToken: Int
}

struct TransactionData: Codable {
    let to: String
    let data: String
    let value: String
    let chainId: Int
}

struct TransactionActionResponse: Codable {
    let message: String
    let listingId: String
    // Backend returns specific keys for different actions, we can make them optional
    let purchaseTransactionHash: String?
    let delistTransactionHash: String?
    let listingTransactionHash: String?
}

// Helper to handle mixed types (String or Int) in JSON "value" fields
struct AnyCodable: Codable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            value = intVal
        } else if let stringVal = try? container.decode(String.self) {
            value = stringVal
        } else if let doubleVal = try? container.decode(Double.self) {
            value = doubleVal
        } else {
            // Check for bool? or just default to string representation if needed
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable value cannot be decoded"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let intVal = value as? Int {
            try container.encode(intVal)
        } else if let stringVal = value as? String {
            try container.encode(stringVal)
        } else if let doubleVal = value as? Double {
            try container.encode(doubleVal)
        }
    }
}
