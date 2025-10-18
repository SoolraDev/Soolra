
import Foundation
import WebKit

final class YabalaliViewModel: ObservableObject, WebGameViewModel, ControllerServiceDelegate {
    let startURL: URL
    weak var webView: WKWebView?
    var dismiss: (() -> Void)?

    init(startURL: URL) {
        self.startURL = startURL
    }

    func controllerDidPress(action: SoolraControllerAction, pressed: Bool) {
        // Always send to the web page if it exists
        sendGameHostPress(action: action, pressed: pressed)

        // Handle local dismiss shortcut
        if pressed {
            switch action {
            case .b, .menu, .select:
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.dismiss?()
                }
            default:
                break
            }
        }
    }

    private func sendGameHostPress(action: SoolraControllerAction, pressed: Bool) {
        guard let webView else { return }
        let js = """
        if (window.GameHost && typeof window.GameHost.press === 'function') {
            window.GameHost.press({ action: '\(action.rawValue)', pressed: \(pressed ? "true" : "false") });
        }
        """
        print("Evaluating JS → \(js)")
        webView.evaluateJavaScript(js, completionHandler: nil)
    }
}
