import Foundation
import WebKit

final class StackerViewModel: ObservableObject, WebGameViewModel, ControllerServiceDelegate {
    let startURL: URL
    weak var webView: WKWebView?
    private var keyState = Set<Int>()
    var dismiss: (() -> Void)?

    init(startURL: URL) { self.startURL = startURL }

    
    func controllerDidPress(action: SoolraControllerAction, pressed: Bool) {
        print("Action: \(action), pressed: \(pressed)")


        switch action {
        case .a, .b, .y, .start:
            if pressed {
                sendKey(type: "keydown", which: 32, key: " ", codeName: "Space")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    self?.sendKey(type: "keyup", which: 32, key: " ", codeName: "Space")
                }
            }

        case .x, .select, .menu:
            if pressed { DispatchQueue.main.async { [weak self] in self?.dismiss?() } }

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
            (() => {
                const start = document.getElementById('start');
                const reload = document.querySelector('.over-button-b.js-reload');
                const startDisplay = document.querySelector('div.landing.hide').style.display;
                const modalDisplay = document.getElementById('modal').style.display;

                if (reload && modalDisplay == 'block') {
                    console.log('Clicking reload button');
                    reload.click();
                    return;
                }

                if (start && startDisplay == 'block') {
                    console.log('Clicking start button');
                    start.click();
                    return;
                }

                var e = new KeyboardEvent('\(type)', {
                    key: '\(key)',
                    code: '\(codeName)',
                    keyCode: \(which),
                    which: \(which),
                    bubbles: true,
                    cancelable: true
                });
                document.dispatchEvent(e);
            })();
        """)
    }




    private func injectJS(_ js: String, completion: ((Any?, Error?) -> Void)? = nil) {
        DispatchQueue.main.async {
            guard let webView = self.webView else {
                completion?(nil, NSError(domain: "NoWebView", code: 0)); return
            }
            webView.evaluateJavaScript(js, completionHandler: completion)
        }
    }
}
