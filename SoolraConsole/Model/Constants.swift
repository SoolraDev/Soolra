//
//  Constants.swift
//  SOOLRA
//
//  Created by Michael Essiet on 10/11/2025.
//

import Foundation

struct Configuration {
    // MARK: - API Details
    
    #if DEBUG
    // --- DEVELOPMENT ---
    // This code will only be used when running in the Debug configuration (from Xcode).
    static let privyAppId = "cmi1t9gor026hl80c5lemdxbr"
    static let privyClientId = "client-WY6TAYNcsf7GgVJHBBPzTjeoQsFwxc9kpnMtriSSQ4jda"
    static let soolraBackendURL = "http://localhost:3000"
    static let enableDiagnostics = true

    #else
    // --- PRODUCTION ---
    // This code will be used for all other builds (Release, TestFlight, App Store).
    static let privyAppId = "cmi1t9gor026hl80c5lemdxbr"
    static let privyClientId = "client-WY6TAYNcsf7GgVJHBBPzTjeoQsFwxc9kpnMtriSSQ4jda"
    static let soolraBackendURL = "https://api.soolra.com"
    static let enableDiagnostics = false
    #endif

    // MARK: - Other Constants
    
    static let defaultTimeout: TimeInterval = 30
}
