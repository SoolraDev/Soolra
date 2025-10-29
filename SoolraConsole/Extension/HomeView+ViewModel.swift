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
    @Published var isCarouselMode: Bool = true  // Toggle between carousel and grid

    let controllerService = BluetoothControllerService.shared

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
        if !pressed {
            return
        }
        print("homeview+viewmodel Controller pressed - \(pressed), action: \(action.rawValue)")
        
        var endIndex = focusedButtonIndex
        let isInGameArea = focusedButtonIndex >= 4

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
            // Grid mode or nav button area: original logic
            switch action {
            case .up:
                if (3...6).contains(endIndex) {
                    endIndex = 2
                } else {
                    endIndex -= 4
                }
            case .down:
                if endIndex == 0 || endIndex == 1 {
                    endIndex = 2
                } else if endIndex == 2 {
                    endIndex = 3
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
        focusedButtonIndex = min(max(endIndex, 0), maximumIndex)
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
