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
            "authorization": "Bearer \(jwt)",  // Common practice
        ]
    }

    func clear() {
        currentPrivyId = nil
        currentJwt = nil
    }
}

class ApiClient {
    private let baseURL = URL(string: Configuration.soolraBackendURL)!

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
                print("🚨 Fetch metrics failed: Invalid response")
                return nil
            }
            // 1. Create a JSONDecoder instance.
            let decoder = JSONDecoder()
            // 2. Set the date decoding strategy to handle ISO 8601 strings.
            decoder.dateDecodingStrategy = .iso8601

            // 3. Use the configured decoder.
            let metrics = try decoder.decode(
                UserMetricsResponse.self,
                from: data
            )
            return metrics
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
            duration: Int(session.duration * 1000)  // Convert seconds to milliseconds
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
                print("🚨 Post session failed: Invalid response")
                return false
            }
            print("✅ Successfully uploaded session for \(session.gameName)")
            return true
        } catch {
            print("🚨 Error posting session: \(error)")
            return false
        }
    }
    
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
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("🚨 Fetch NFTs failed: Invalid response")
                // Optional: Try to read server error message
                if let errorJson = try? JSONSerialization.jsonObject(with: data) {
                    print("Server Error: \(errorJson)")
                }
                return nil
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let nfts = try decoder.decode([NFTMetadata].self, from: data)
            return nfts
        } catch {
            print("🚨 Error fetching NFTs: \(error)")
            return nil
        }
    }
}

// MARK: JSON models
// Represents a game session that has been completed and is waiting to be uploaded.
struct GameSessionRecord: Codable, Identifiable {
    let id: UUID
    let gameName: String
    let duration: TimeInterval  // Duration in seconds
    let score: Int
    let recordedAt: Date
}

// Represents the JSON body for the POST request.
struct MetricsUploadBody: Codable {
    struct GameSessionPayload: Codable {
        let gameName: String
        let score: Int
        let duration: Int  // Duration in milliseconds for the backend
    }
    let gameSession: GameSessionPayload?
}

// Represents the expected JSON response from the GET request.
struct UserMetricsResponse: Codable {
    let id: String
    let totalTimePlayed: Int  // Milliseconds from backend
    let points: Int
    let lastUpdated: Date
    let ranking: Int?
    // Add other fields like points, ranking, etc., if you need them in the app
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
    let txHash: String
    let mintedAt: Date
    
    var id: Int { tokenId }
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
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value cannot be decoded")
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
