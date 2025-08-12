import Foundation
import WebKit

final class Game2048ViewModel: ObservableObject, WebGameViewModel, ControllerServiceDelegate {
    let startURL: URL
    weak var webView: WKWebView?
    private var keyState = Set<String>()
    var dismiss: (() -> Void)?

    init(startURL: URL) {
        self.startURL = startURL
    }

    func controllerDidPress(action: SoolraControllerAction, pressed: Bool) {
        print("🎮 Controller input: \(action) — \(pressed ? "Pressed" : "Released")")

        switch action {
        case .left:  pressed ? keyDown(which: 37) : keyUp(which: 37)
        case .right: pressed ? keyDown(which: 39) : keyUp(which: 39)
        case .up:    pressed ? keyDown(which: 38) : keyUp(which: 38)
        case .down:  pressed ? keyDown(which: 40) : keyUp(which: 40)
        case .b, .select, .menu:
            if pressed {
                DispatchQueue.main.async { [weak self] in
                    self?.dismiss?()
                }
            }
        default:
            break
        }
    }

    private func keyDown(which: Int) {
        injectJS("""
          (function(){
            var e = new KeyboardEvent('keydown', {bubbles:true, cancelable:true});
            Object.defineProperty(e, 'which',   {value:\(which)});
            Object.defineProperty(e, 'keyCode', {value:\(which)});
            document.dispatchEvent(e);
          })();
        """)
    }

    private func keyUp(which: Int) {
        injectJS("""
          (function(){
            var e = new KeyboardEvent('keyup', {bubbles:true, cancelable:true});
            Object.defineProperty(e, 'which',   {value:\(which)});
            Object.defineProperty(e, 'keyCode', {value:\(which)});
            document.dispatchEvent(e);
          })();
        """)
    }

    private func pressKey(_ key: String) {
        guard !keyState.contains(key) else { return }
        keyState.insert(key)
        injectJS("""
            window.dispatchEvent(new KeyboardEvent('keydown', {
                key: '\(key)', code: '\(key)', bubbles: true
            }));
        """)
    }

    private func releaseKey(_ key: String) {
        guard keyState.contains(key) else { return }
        keyState.remove(key)
        injectJS("""
            window.dispatchEvent(new KeyboardEvent('keyup', {
                key: '\(key)', code: '\(key)', bubbles: true
            }));
        """)
    }

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
