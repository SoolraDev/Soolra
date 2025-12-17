import Foundation
import WebKit

final class HexGlViewModel: ObservableObject, WebGameViewModel, ControllerServiceDelegate {
    let startURL: URL
    weak var webView: WKWebView?
    private var keyState = Set<Int>()
    private var needsStart = true
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
            
        case .y:
            print("pressed \(action)")
            handle(65, "a", "KeyA")

        case .a:
            print("pressed \(action)")
            handle(68, "d", "KeyD")

        case .right:
            handle(39, "ArrowRight", "ArrowRight")
        case .down:
            handle(40, "ArrowDown", "ArrowDown")
        case .x, .select, .menu:
            if pressed { DispatchQueue.main.async { [weak self] in self?.dismiss?() } }
        default:
            break
        }
    }
    
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
        if needsStart {
            triggerStart()
        }
        
        injectJS("""
        var e = new KeyboardEvent('\(type)', {
            key: '\(key)',
            code: '\(codeName)',
            keyCode: \(which),
            which: \(which),
            bubbles: true,
            cancelable: true
        });
        document.dispatchEvent(e);x
        """)
    }
    private func triggerStart() {
        injectJS("""
        var step2 = document.getElementById('step-2');
        if (step2 && step2.style.display !== 'none') {
            step2.click();
            'found';
        } else {
            'not found';
        }
        """) { [weak self] result, error in
            if let resultString = result as? String {
                print("Step-2 click result: \(resultString)")
                if resultString == "found" {
                    self?.needsStart = false
                }
            }
            if let error = error {
                print("Step-2 click error: \(error)")
            }
        }
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
