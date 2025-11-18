//
//  UserMetrics.swift
//  SOOLRA
//
//  Created by Michael Essiet on 18/11/2025.
//
// UserMetrics.swift

import Foundation
import Combine

/// A simple, observable data model for holding a user's metrics.
/// This object is managed by the DataManager and observed by the UI.
@MainActor
public class UserMetrics: ObservableObject, Identifiable {
    public let id: String // Now conforms to identifiable

    @Published public var points: Int
    @Published public var lastUpdated: Date
    @Published public var ranking: Int? // Ranking can be optional
    @Published public var totalTimePlayed: TimeInterval // Stored in seconds

    init(
        id: String,
        points: Int,
        lastUpdated: Date,
        ranking: Int?,
        totalTimePlayed: TimeInterval
    ) {
        self.id = id
        self.points = points
        self.lastUpdated = lastUpdated
        self.ranking = ranking
        self.totalTimePlayed = totalTimePlayed
    }
    
    /// Creates a UserMetrics object from the API response DTO.
    convenience init(from response: UserMetricsResponse) {
        self.init(
            id: response.id,
            points: response.points,
            lastUpdated: response.lastUpdated,
            ranking: response.ranking,
            totalTimePlayed: TimeInterval(response.totalTimePlayed / 1000) // Convert ms to seconds
        )
    }
}
