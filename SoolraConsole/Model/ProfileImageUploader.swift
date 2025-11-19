//
//  ProfileImageUploader.swift
//  SOOLRA
//
//  Created by Michael Essiet on 19/11/2025.
//
import UIKit

// A helper extension to make building the multipart body easier.
fileprivate extension Data {
    mutating func append(string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

enum UploadError: Error, LocalizedError {
    case failedToGetData
    case badServerResponse(statusCode: Int, message: String)
    case couldNotDecodeServerResponse

    public var errorDescription: String? {
        switch self {
        case .failedToGetData:
            return "Could not convert UIImage to JPEG data."
        case .badServerResponse(let statusCode, let message):
            return "Server responded with error \(statusCode): \(message)"
        case .couldNotDecodeServerResponse:
            return "Could not decode the server's successful response."
        }
    }
}

class ProfileImageUploader {

    /// Uploads a user's profile image to the backend using multipart/form-data.
    /// - Parameters:
    ///   - image: The UIImage to upload.
    ///   - userId: The ID of the user.
    /// - Returns: The public URL of the newly uploaded image.
    static func upload(image: UIImage, for userId: String) async throws -> String {
        guard let url = URL(string: "\(Configuration.soolraBackendURL)/v1/users/\(userId)/image") else {
            throw URLError(.badURL)
        }

        // 1. Get authentication headers
        guard let headers = AuthManager.shared.getAuthHeaders() else {
            throw URLError(.userAuthenticationRequired)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers // Set auth headers first

        // 2. Create the multipart/form-data body
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Compress the image to JPEG data. 0.8 is a good balance of quality and size.
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw UploadError.failedToGetData
        }
        
        var httpBody = Data()
        
        // Add the image data part
        httpBody.append(string: "--\(boundary)\r\n")
        // The `name` must match the key in your Elysia body object: `file`.
        httpBody.append(string: "Content-Disposition: form-data; name=\"file\"; filename=\"profile.jpg\"\r\n")
        httpBody.append(string: "Content-Type: image/jpeg\r\n\r\n")
        httpBody.append(imageData)
        httpBody.append(string: "\r\n")
        
        // Add the closing boundary
        httpBody.append(string: "--\(boundary)--\r\n")
        
        request.httpBody = httpBody

        // 3. Perform the upload request.
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UploadError.badServerResponse(statusCode: -1, message: "Invalid HTTP response.")
        }
        
        // 4. Handle success or failure based on status code
        guard httpResponse.statusCode == 200 else {
            // Try to decode the error message from the server
            if let errorBody = try? JSONDecoder().decode([String: String].self, from: data),
               let errorMessage = errorBody["error"] {
                throw UploadError.badServerResponse(statusCode: httpResponse.statusCode, message: errorMessage)
            } else {
                // Fallback if the error body isn't in the expected JSON format
                throw UploadError.badServerResponse(statusCode: httpResponse.statusCode, message: "No error message from server.")
            }
        }

        // 5. Decode the successful JSON response to get the new image URL.
        guard let result = try? JSONDecoder().decode([String: String].self, from: data),
              let newUrl = result["profileImageUrl"] else {
            throw UploadError.couldNotDecodeServerResponse
        }
        
        return newUrl
    }
}
