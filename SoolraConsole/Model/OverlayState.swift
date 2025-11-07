//
//  OverlayState.swift
//  SOOLRA
//
//  Created by Michael Essiet on 07/11/2025.
//
import SwiftUI

public enum ActiveOverlay: Hashable {
    case market
    case profile
    case wallet
}

@MainActor
public class OverlayState: ObservableObject {
    @Published public var activeOverlay: ActiveOverlay? = nil
    
    // --- BINDING COMPUTED PROPERTIES ---
    // These now return Binding<Bool> which allows two-way interaction
    // with SwiftUI controls like Toggle or .sheet(isPresented:)
    
    public var isMarketOverlayVisible: Binding<Bool> {
        Binding(
            get: { self.activeOverlay == .market },
            set: { newValue in self.update(overlay: .market, isVisible: newValue) }
        )
    }
    
    public var isProfileOverlayVisible: Binding<Bool> {
        Binding(
            get: { self.activeOverlay == .profile },
            set: { newValue in self.update(overlay: .profile, isVisible: newValue) }
        )
    }
    
    public var isWalletOverlayVisible: Binding<Bool> {
        Binding(
            get: { self.activeOverlay == .wallet },
            set: { newValue in self.update(overlay: .wallet, isVisible: newValue) }
        )
    }
    
    private func update(overlay: ActiveOverlay, isVisible: Bool) {
        if isVisible {
            activeOverlay = overlay
        } else {
            // Only set to nil if the overlay being dismissed is the currently active one.
            if activeOverlay == overlay {
                activeOverlay = nil
            }
        }
    }
    
    public init() {}
}

@MainActor public let overlayState = OverlayState()
