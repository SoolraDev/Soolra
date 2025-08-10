import Foundation
import WebKit

final class SlitherViewModel: ObservableObject, ControllerServiceDelegate {
    weak var webView: WKWebView?
    private var keyState = Set<String>()
    var dismiss: (() -> Void)?  // Add this
    private var activeTouchID: Int? = nil
    private var movementTouchID: Int?
    private var movementAngle: Double = 0.0  // Radians
    private var movementTimer: Timer?
    private var rotationDirection: Int = 0  // -1 for left, 1 for right, 0 for idle

    private let movementRadius = 150.0
    private let movementCenterX = 300.0
    private let movementCenterY = 300.0

    private var isGameStarted = false


    func controllerDidPress(action: SoolraControllerAction, pressed: Bool) {
        print("🎮 Controller input: \(action) — \(pressed ? "Pressed" : "Released")")

        switch action {
        case .left:
            if pressed {
                keyDown(which: 37) // ArrowLeft
            } else {
                keyUp(which: 37)
            }

        case .right:
            if pressed {
                keyDown(which: 39) // ArrowRight
            } else {
                keyUp(which: 39)
            }

        case .up:
            if pressed {
                keyDown(which: 38) // ArrowUp
            } else {
                keyUp(which: 38)
            }

        case .down:
            if pressed {
                keyDown(which: 40) // ArrowDown
            } else {
                keyUp(which: 40)
            }
        case .b:
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
        guard !keyState.contains(key) else {
            print("⬅️ Ignoring repeated press for key: \(key)")
            return
        }
        keyState.insert(key)
        print("⬇️ Pressing key: \(key)")
        injectJS("""
            window.dispatchEvent(new KeyboardEvent('keydown', {
                key: '\(key)', code: '\(key)', bubbles: true
            }));
        """)
    }

    private func releaseKey(_ key: String) {
        guard keyState.contains(key) else {
            print("⬆️ Ignoring release for unpressed key: \(key)")
            return
        }
        keyState.remove(key)
        print("⬆️ Releasing key: \(key)")
        injectJS("""
            window.dispatchEvent(new KeyboardEvent('keyup', {
                key: '\(key)', code: '\(key)', bubbles: true
            }));
        """)
    }

    private func injectJS(_ js: String, completion: ((Any?, Error?) -> Void)? = nil) {
        DispatchQueue.main.async {
            guard let webView = self.webView else {
                print("❌ injectJS: webView is nil")
                completion?(nil, NSError(domain: "NoWebView", code: 0))
                return
            }

            print("📤 Injecting JS: \(js)")
            webView.evaluateJavaScript(js) { result, error in
                if let error = error {
                    print("❌ JS Eval Error: \(error.localizedDescription)")
                } else {
                    print("✅ JS injected successfully")
                }
                completion?(result, error)
            }
        }
    }

   



}
