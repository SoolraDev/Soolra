//
//  WebGame.swift
//  SOOLRA
//
//  Created by Kai Yoshida on 10/08/2025.
//

import Foundation
import UIKit
import SwiftUI


struct WebGame: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    let icon: UIImage?
    let makeViewModel: () -> any WebGameViewModel
    let makeWrapper: (_ vm: any WebGameViewModel, _ onClose: @escaping () -> Void) -> AnyView
}

protocol WebGameViewModel: AnyObject {
    var startURL: URL { get }
    // add per‑game state as needed, e.g. score bindings, mute, etc.
}
