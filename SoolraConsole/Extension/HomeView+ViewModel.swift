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
//    @Published var romCount: Int = 0
    @Published var itemsCount: Int = 0
    @Published var searchQuery: String = ""

    let controllerService = BluetoothControllerService.shared

    private init() {
        controllerService.delegate = self
    }

    func setAsDelegate() {
        print("HomeView: Explicitly setting controller delegate")
        controllerService.delegate = self
        // Ensure we maintain the last known state
        objectWillChange.send()
    }

    func onAppear() {
        // Only set delegate if there isn't one already
        if BluetoothControllerService.shared.delegate == nil {
            print("HomeView: Setting controller delegate")
            controllerService.delegate = self
            // Ensure we maintain the last known state
            objectWillChange.send()
        }
    }

    func controllerDidPress(action: SoolraControllerAction, pressed: Bool) {
        if !pressed {
            return
        }
        print("homeview+viewmodel Controller pressed - \(pressed), action: \(action.rawValue)")
        var endIndex = focusedButtonIndex

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

        let maximumIndex = 3  + itemsCount
        focusedButtonIndex = min(max(endIndex, 0), maximumIndex)
    }

//    func updateRomCount(_ count: Int) {
//        romCount = count
//    }
    
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
