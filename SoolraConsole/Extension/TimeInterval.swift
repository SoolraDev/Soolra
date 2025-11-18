//
//  TimeInterval.swift
//  SOOLRA
//
//  Created by Michael Essiet on 02/11/2025.
//

import Foundation

extension TimeInterval {

    /// A static formatter to avoid creating new instances repeatedly, which is costly.
    private static let wordedTimeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        
        // 1. Specify the units you want to see in the output
        formatter.allowedUnits = [.year, .month, .day, .hour, .minute, .second]
        
        // 2. Choose the style for the unit names (e.g., "days", "hr", "m")
        formatter.unitsStyle = .full
        
        // 3. The magic property: limits the output to the single largest unit.
        //    "12 days, 3 hours" would become just "12 days".
        formatter.maximumUnitCount = 1
        
        return formatter
    }()

    /// Converts the time interval in seconds to a human-readable, worded string.
    /// - Example: 120 -> "2 minutes"
    /// - Example: 100000 -> "1 day"
    func toWordedString() -> String {
        // The formatter returns an optional string, so we provide a fallback.
        return Self.wordedTimeFormatter.string(from: self) ?? "0 seconds"
    }
}
