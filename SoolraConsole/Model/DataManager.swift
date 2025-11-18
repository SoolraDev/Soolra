//
//  DataManager.swift
//  SOOLRA
//
//  Created by Michael Essiet on 30/10/2025.
//
// DataManager.swift

import Foundation

/// A singleton manager responsible for fetching and holding the current user's metrics.
/// The UI should observe the `userMetrics` property to display data.
@MainActor
public class DataManager: ObservableObject {
    @Published public var userMetrics: UserMetrics?
    
    private let apiClient = ApiClient()

    /// Fetches the latest metrics for a given user and updates the published `userMetrics` property.
    /// This should be called after a user successfully logs in.
    func fetchUserMetrics(userId: String) async {
        guard let response = await apiClient.fetchUserMetrics(userId: userId) else {
            print("❌ DataManager: Failed to fetch user metrics from API.")
            return
        }
        
        // Update the published property on the main thread.
        self.userMetrics = UserMetrics(from: response)
        print("✅ DataManager: Successfully fetched and updated user metrics.")
    }
    
    /// Manually triggers a refresh of the current user's metrics from the backend.
    /// This is ideal for UI actions like pull-to-refresh.
    public func refresh() async {
        // Ensure we have a user to refresh.
        guard let currentUserId = userMetrics?.id else {
            print("⚠️ DataManager: Cannot refresh, no user is currently logged in.")
            return
        }
        
        print("🔄 DataManager: Refreshing metrics for user \(currentUserId)...")
        // Simply call the existing fetch function with the current user's ID.
        await fetchUserMetrics(userId: currentUserId)
    }
    
    /// Clears the current user's metrics.
    /// This should be called when a user logs out.
    func clear() {
        self.userMetrics = nil
        print("🧹 DataManager: User metrics cleared.")
    }
}

// Create a global singleton instance for easy access throughout the app.
@MainActor
public let dataManager = DataManager()
