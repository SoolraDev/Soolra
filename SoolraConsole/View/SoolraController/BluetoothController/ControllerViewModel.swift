//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import SwiftUI
import GameController

struct ControllerAction: Equatable {
    let action: SoolraControllerAction
    let pressed: Bool
}

class ControllerViewModel: ObservableObject, ControllerServiceDelegate {
    static let shared = ControllerViewModel()
    
    @Published var lastAction: ControllerAction?

    private init() {
        BluetoothControllerService.shared.delegate = self
    }

    func controllerDidPress(action: SoolraControllerAction, pressed: Bool) {
        let newAction = ControllerAction(action: action, pressed: pressed)
        if lastAction != newAction {
            lastAction = newAction
        }
    }
}
