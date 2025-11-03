//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import Foundation
import SwiftUI

public class HomeViewModel: ObservableObject, ControllerServiceDelegate {
    public static let shared = HomeViewModel()
    
    @Published var isPresented = false
    @Published var selectedGameIndex: Int?
    @Published var focusedButtonIndex: Int = 0
    @Published var itemsCount: Int = 0
    @Published var searchQuery: String = ""
    @Published var isCarouselMode: Bool = true
    
    let controllerService = BluetoothControllerService.shared
    
    // Repeat timer for held buttons
    private var repeatTimer: Timer?
    private var currentHeldAction: SoolraControllerAction?
    private var isProcessingScroll: Bool = false
    private var lastPressTimestamp: Date = Date()
    private var pendingTimerTask: DispatchWorkItem?  // Track the delayed timer creation

    private init() {
        controllerService.delegate = self
    }

    func setAsDelegate() {
        print("HomeView: Explicitly setting controller delegate")
        controllerService.delegate = self
        objectWillChange.send()
    }

    func onAppear() {
        if BluetoothControllerService.shared.delegate == nil {
            print("HomeView: Setting controller delegate")
            controllerService.delegate = self
            objectWillChange.send()
        }
    }

    func controllerDidPress(action: SoolraControllerAction, pressed: Bool) {
        print("🎮 EVENT: \(action.rawValue) pressed=\(pressed)")
        let isInGameArea = focusedButtonIndex >= 4
        let isNavigationAction = [.up, .down, .left, .right].contains(action)
        
        if !pressed {
            print("🛑 RELEASE detected for \(action.rawValue) - STOPPING ALL TIMERS")
            // ANY button release stops ALL timers AND pending timer creation
            stopRepeating()
            return
        }
        
        // If already holding this button, ignore duplicate press events
        if currentHeldAction == action && repeatTimer != nil {
            return
        }
        
        // Execute single move immediately
        executeAction(action, isInGameArea: isInGameArea)
        
        // Start repeat timer for navigation in carousel mode
        if isCarouselMode && isInGameArea && isNavigationAction {
            // ALWAYS stop any existing timer before starting a new one
            stopRepeating()
            
            currentHeldAction = action  // Set BEFORE the delay so release can catch it
            
            // After 0.3s, start repeating every 0.1s
            // After 0.3s, start repeating every 0.1s
            let task = DispatchWorkItem { [weak self] in
                guard let self = self, self.currentHeldAction == action else { return }
                
                print("⏰ Timer starting for \(action.rawValue)")
                self.repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in  // Changed from 0.1 to 0.12
                    guard let self = self else { return }
                    self.executeAction(action, isInGameArea: isInGameArea)
                }
            }
            
            pendingTimerTask = task
            // Clear processing flag after animation time
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) { [weak self] in  // Changed from 0.09 to 0.11
                self?.isProcessingScroll = false
            }        }
    }
    
    private func executeAction(_ action: SoolraControllerAction, isInGameArea: Bool) {
        print("⚡ executeAction called: \(action.rawValue), isInGameArea: \(isInGameArea), isProcessing: \(isProcessingScroll)")
        
        // Skip if already processing a scroll (prevents queue buildup)
        guard !isProcessingScroll else {
            print("⏭️ Skipped - already processing")
            return
        }
        
        var endIndex = focusedButtonIndex

        if isCarouselMode && isInGameArea {
            // Carousel mode: single-item vertical navigation
            switch action {
            case .up:
                endIndex = max(4, focusedButtonIndex - 1)
            case .down:
                endIndex = min(3 + itemsCount, focusedButtonIndex + 1)
            case .left:
                endIndex -= 1
            case .right:
                endIndex += 1
            case .a, .b, .x, .y:
                selectedGameIndex = focusedButtonIndex
                return
            default:
                return
            }
        } else {
            // Grid mode or nav button area
            switch action {
            case .up:
                if (3...6).contains(endIndex) {
                    endIndex = 2
                } else {
                    endIndex -= 4
                }
            case .down:
                // From any nav button (0-3), jump directly to first carousel item
                if endIndex < 4 {
                    endIndex = 4
                } else {
                    endIndex += 4
                }
            case .left:
                endIndex -= 1
            case .right:
                endIndex += 1
            case .a, .b, .x, .y:
                selectedGameIndex = focusedButtonIndex
                return
            default:
                return
            }
        }

        let maximumIndex = 3 + itemsCount
        let newIndex = min(max(endIndex, 0), maximumIndex)
        
        // Stop repeating if we've hit a boundary
        if newIndex == focusedButtonIndex {
            stopRepeating()
            return
        }
        
        // Mark as processing and update index
        isProcessingScroll = true
        focusedButtonIndex = newIndex
        
        // Clear processing flag after animation time
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) { [weak self] in
            self?.isProcessingScroll = false
        }
    }
    
    private func stopRepeating() {
        print("🛑 stopRepeating - cancelling timer and pending task")
        pendingTimerTask?.cancel()  // Cancel the delayed timer creation
        pendingTimerTask = nil
        repeatTimer?.invalidate()
        repeatTimer = nil
        currentHeldAction = nil
        isProcessingScroll = false
    }
    
    func updateItemsCount(_ count: Int) {
        itemsCount = count
    }
}

extension HomeView {
    enum PopList: CaseIterable {
        case loadDefault
        case addRom
    }
}

extension HomeView.PopList {
    var description: String {
        switch self {
        case .loadDefault: return "Load default games"
        case .addRom: return "Add game"
        }
    }
}
