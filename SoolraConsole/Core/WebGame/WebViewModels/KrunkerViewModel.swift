//
//  KrunkerViewModel.swift
//  SOOLRA
//
//  Created by Kai Yoshida on 25/08/2025.
//


import Foundation
import WebKit

final class KrunkerViewModel: ObservableObject, WebGameViewModel, ControllerServiceDelegate {
    let startURL: URL
    weak var webView: WKWebView?
    var dismiss: (() -> Void)?

    init(startURL: URL) {
        self.startURL = startURL
    }

    // (Optional) wire controller later; for now we just allow closing with B/menu
    func controllerDidPress(action: SoolraControllerAction, pressed: Bool) {
        guard pressed else { return }
        switch action {
        case .b, .menu, .select:
            dismiss?()
        default:
            break
        }
    }
}
