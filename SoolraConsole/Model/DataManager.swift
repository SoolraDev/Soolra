//
//  DataManager.swift
//  SOOLRA
//
//  Created by Michael Essiet on 30/10/2025.
//
import Foundation
import Combine

public class UserMetrics: ObservableObject {
    let userId: String

    // @Published automatically announces any changes to these properties.
    @Published var points: Int
    @Published var lastUpdated: Date
    @Published var ranking: Int
    @Published var totalTimePlayed: TimeInterval
    
    // A set to store our Combine subscriptions.
    private var cancellables = Set<AnyCancellable>()

    init(
        userId: String,
        points: Int,
        lastUpdated: Date,
        ranking: Int,
        totalTimePlayed: TimeInterval
    ) {
        self.userId = userId
        self.points = points
        self.lastUpdated = lastUpdated
        self.ranking = ranking
        self.totalTimePlayed = totalTimePlayed
        
        // Set up the automatic syncing mechanism when the object is created.
        setupAutoSync()
    }

    private func setupAutoSync() {
        // Map each published property to Void so that merge types align.
        let changesPublisher = $points
            .dropFirst()
            .map { _ in () }
            .merge(with: $ranking.dropFirst().map { _ in () })
            .merge(with: $totalTimePlayed.dropFirst().map { _ in () })
            .eraseToAnyPublisher()

        changesPublisher
            // Wait for a 1.5-second pause in changes before proceeding to prevent too many API requests.
            .debounce(for: DispatchQueue.SchedulerTimeType.Stride.seconds(1.5), scheduler: DispatchQueue.main)
            .sink { [weak self] (_: Void) in
                print("✅ Changes detected. Syncing with backend...")
                self?.syncWithBackend()
            }
            .store(in: &cancellables)
    }

    // This function will be called automatically to send the update.
    func syncWithBackend() {
        // Run the network request in a background task.
        Task {
            do {
                try await updateUserMetricsAPI(metrics: self)
                print("Successfully synced metrics for user \(self.userId)")
            } catch {
                print("❌ Error syncing metrics: \(error.localizedDescription)")
                // Handle the error, e.g., show an alert to the user.
            }
        }
    }
    
    // MARK: - Update Methods
    
    // The 'mutating' keyword is no longer needed because this is a class.
    func update(
        points: Int? = nil,
        ranking: Int? = nil,
        totalTimePlayed: TimeInterval? = nil
    ) {
        self.points = points ?? self.points
        self.ranking = ranking ?? self.ranking
        self.totalTimePlayed = totalTimePlayed ?? self.totalTimePlayed
        
        // If any value was provided and changed, update the timestamp.
        if points != nil || ranking != nil || totalTimePlayed != nil {
            self.lastUpdated = Date()
        }
    }
    
    func incrementPoints(by amount: Int) {
        self.points += amount
        self.lastUpdated = Date()
    }
    
    func incrementTotalTimePlayed(by amount: TimeInterval) {
        self.totalTimePlayed += amount
        self.lastUpdated = Date()
    }
    
    func updateRanking(to newRanking: Int) {
        self.ranking = newRanking
        self.lastUpdated = Date()
    }
}


// MARK: - API Client (Placeholder)

// This would typically be in its own file (e.g., APIClient.swift).
// This is a placeholder for your actual network request function.
private func updateUserMetricsAPI(metrics: UserMetrics) async throws {
    // This Codable struct represents the data you're sending.
    // We don't include userId because it's part of the URL.
    struct MetricsPayload: Codable {
        let points: Int
        let lastUpdated: Date
        let ranking: Int
        let totalTimePlayed: TimeInterval
    }
    
    let payload = MetricsPayload(
        points: metrics.points,
        lastUpdated: metrics.lastUpdated,
        ranking: metrics.ranking,
        totalTimePlayed: metrics.totalTimePlayed
    )

    guard let url = URL(string: "https://yourapi.com/users/\(metrics.userId)/metrics") else {
        throw URLError(.badURL)
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(payload)

    print("Sending update to backend: \(String(data: request.httpBody!, encoding: .utf8) ?? "")")

    let (_, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
        throw URLError(.badServerResponse)
    }
}

