import Foundation
import WebKit

final class UnityGameViewModel: NSObject, ObservableObject, WebGameViewModel, ControllerServiceDelegate, WKNavigationDelegate {
    let startURL: URL
    weak var webView: WKWebView?
    private var keyState = Set<Int>()
    /// Actions this specific game wants delivered through the host input bridge
    /// (window.GameHost.press) instead of synthetic keyboard events. Empty by
    /// default so other Unity games keep their existing keyboard behavior.
    private let bridgeActions: Set<SoolraControllerAction>
    private var bridgePressed = Set<SoolraControllerAction>()
    var dismiss: (() -> Void)?
    @Published var isLoading = true

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.async { self.isLoading = false }
    }

    init(startURL: URL, bridgeActions: Set<SoolraControllerAction> = []) {
        self.startURL = startURL
        self.bridgeActions = bridgeActions
        super.init()
    }

    func controllerDidPress(action: SoolraControllerAction, pressed: Bool) {
        // Game-specific actions routed through the host input bridge. e.g. 6 Ball
        // opts y/b in here so its GameHost remap turns them into piece rotation,
        // without changing how any other Unity game handles those buttons.
        if bridgeActions.contains(action) {
            sendGameHostPress(action: action, pressed: pressed)
            return
        }

        func handle(_ which: Int, _ key: String, _ code: String) {
            pressed ? keyDown(which: which, key: key, codeName: code)
                    : keyUp(which: which, key: key, codeName: code)
        }

        switch action {
        case .left:
            handle(37, "ArrowLeft", "ArrowLeft")
        case .right:
            handle(39, "ArrowRight", "ArrowRight")
        case .up:
            handle(38, "ArrowUp", "ArrowUp")
        case .down:
            handle(40, "ArrowDown", "ArrowDown")
        case .a, .b, .y:
            handle(32, " ", "Space")
            handle(13, "Enter", "Enter")

        case .l:
            handle(76, "l", "KeyL")
        case .r:
            handle(82, "r", "KeyR")

        case .start:
            handle(13, "Enter", "Enter")

        case .select:
            // Routed through the host input bridge (§3/§4 of the embed spec).
            // Maze / 6 Ball implement window.GameHost.press and consume "select".
            sendGameHostPress(action: .select, pressed: pressed)

        case .menu, .x:
            if pressed {
                DispatchQueue.main.async { [weak self] in
                    self?.dismiss?()
                }
            }
        default:
            break
        }
    }

    // MARK: - Host input bridge (window.GameHost.press)
    private func sendGameHostPress(action: SoolraControllerAction, pressed: Bool) {
        // Dedupe repeats so a held button doesn't fire multiple press/release events.
        if pressed {
            guard !bridgePressed.contains(action) else { return }
            bridgePressed.insert(action)
        } else {
            guard bridgePressed.contains(action) else { return }
            bridgePressed.remove(action)
        }
        injectJS("""
        if (window.GameHost && typeof window.GameHost.press === 'function') {
            window.GameHost.press({ action: '\(action.rawValue)', pressed: \(pressed ? "true" : "false") });
        }
        """)
    }
    
    // MARK: - Key dispatch
    private func keyDown(which: Int, key: String, codeName: String) {
        guard !keyState.contains(which) else { return }
        keyState.insert(which)
        sendKey(type: "keydown", which: which, key: key, codeName: codeName)
    }
    
    private func keyUp(which: Int, key: String, codeName: String) {
        guard keyState.contains(which) else { return }
        keyState.remove(which)
        sendKey(type: "keyup", which: which, key: key, codeName: codeName)
    }
    
    private func sendKey(type: String, which: Int, key: String, codeName: String) {
        injectJS("""
        var e = new KeyboardEvent('\(type)', {
            key: '\(key)',
            code: '\(codeName)',
            keyCode: \(which),
            which: \(which),
            bubbles: true,
            cancelable: true
        });
        document.dispatchEvent(e);
        """)
    }
    
    // MARK: - JS bridge
    private func injectJS(_ js: String, completion: ((Any?, Error?) -> Void)? = nil) {
        DispatchQueue.main.async {
            guard let webView = self.webView else {
                completion?(nil, NSError(domain: "NoWebView", code: 0))
                return
            }
            webView.evaluateJavaScript(js, completionHandler: completion)
        }
    }
}
