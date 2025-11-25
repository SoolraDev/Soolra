import Foundation
import WebKit

final class TowerViewModel: ObservableObject, WebGameViewModel, ControllerServiceDelegate {
    let startURL: URL
    weak var webView: WKWebView?
    private var keyState = Set<Int>()
    private var needsStart = true     // stay in "press start" mode until success
    var dismiss: (() -> Void)?

    init(startURL: URL) { self.startURL = startURL }

    func controllerDidPress(action: SoolraControllerAction, pressed: Bool) {
        func handle(_ which: Int, _ key: String, _ code: String) {
            pressed ? keyDown(which: which, key: key, codeName: code)
                    : keyUp(which: which, key: key, codeName: code)
        }


        switch action {
        case .left:
            handle(37, "ArrowLeft", "ArrowLeft")
            
        case .up:
            handle(38, "ArrowUp", "ArrowUp")
            

//        case .y, .b, .a:
        case .y, .b, .a:
            print("pressed \(action)")
            if pressed {
                sendKey(type: "keydown", which: 32, key: " ", codeName: "Space")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    self?.sendKey(type: "keyup", which: 32, key: " ", codeName: "Space")
                }
            }



        case .right: // A normally Right
                handle(39, "ArrowRight", "ArrowRight")

        case .down: // B normally Down
                handle(40, "ArrowDown", "ArrowDown")


        case .x, .select, .menu:
            if pressed { DispatchQueue.main.async { [weak self] in self?.dismiss?() } }

        default:
            break
        }
    }

    // MARK: - Key dispatch (key/code/which/keyCode) + focus canvas
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
//        print(js)
        DispatchQueue.main.async {
            guard let webView = self.webView else { completion?(nil, NSError(domain: "NoWebView", code: 0)); return }
            webView.evaluateJavaScript(js, completionHandler: completion)
        }
    }
}
