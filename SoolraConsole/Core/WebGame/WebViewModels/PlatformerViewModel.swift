import Foundation
import WebKit

final class PlatformerViewModel: ObservableObject, WebGameViewModel, ControllerServiceDelegate {
    let startURL: URL
    weak var webView: WKWebView?
    private var keyState = Set<Int>()
    var dismiss: (() -> Void)?

    init(startURL: URL) {
        self.startURL = startURL
    }

    func controllerDidPress(action: SoolraControllerAction, pressed: Bool) {
        func handle(_ which: Int, _ key: String, _ code: String) {
            pressed ? keyDown(which: which, key: key, codeName: code)
                    : keyUp(which: which, key: key, codeName: code)
        }

        switch action {
        case .left:
            handle(37, "ArrowLeft", "ArrowLeft")
        case .right:
            handle(39, "ArrowRight", "ArrowRight")
        case .up, .a, .b:
            handle(38, "ArrowUp", "ArrowUp")
        case .down:
            handle(40, "ArrowDown", "ArrowDown")
        case .l:
            handle(76, "l", "KeyL")
        case .r:
            handle(82, "r", "KeyR")
        case .start:
            handle(13, "Enter", "Enter")
        case .menu, .x, .select:
            if pressed {
                DispatchQueue.main.async { [weak self] in
                    self?.dismiss?()
                }
            }
        default:
            break
        }
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
