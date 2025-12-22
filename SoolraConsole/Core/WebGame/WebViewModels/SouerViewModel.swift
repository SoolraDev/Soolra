import Foundation
import WebKit

final class SouerViewModel: ObservableObject, WebGameViewModel, ControllerServiceDelegate, JoystickControllerDelegate {
    let startURL: URL
    weak var webView: WKWebView?
    private var keyState = Set<Int>()
    private var mouseX: CGFloat = 0
    private var mouseY: CGFloat = 0
    private var isMouseDown = false
    var dismiss: (() -> Void)?
    private var canvasCenterX: CGFloat = 200
    private var canvasCenterY: CGFloat = 200
    private var currentJoystickX: Float = 0
    private var currentJoystickY: Float = 0
    private var joystickTimer: Timer?
    private var weaponSlot: Int = 2  // Start at 2

    init(startURL: URL) {
        self.startURL = startURL
        // Start mouse in center
        self.mouseX = UIScreen.main.bounds.width / 2
        self.mouseY = UIScreen.main.bounds.height / 2
    }
    
    func controllerDidPress(action: SoolraControllerAction, pressed: Bool) {
        func handle(_ which: Int, _ key: String, _ code: String) {
            pressed ? keyDown(which: which, key: key, codeName: code)
                    : keyUp(which: which, key: key, codeName: code)
        }
        
        switch action {
        case .left:
            handle(65, "a", "KeyA")
        case .up:
            handle(87, "w", "KeyW")
        case .right:
            handle(68, "d", "KeyD")
        case .down:
            handle(83, "s", "KeyS")
        case .a:  // Shoot
            simulateMouseClick(pressed: pressed)
        case .b:  // Space
            handle(32, " ", "Space")
        case .y:  // Cycle weapons 1-7
                if pressed {
                    let keyCode = 48 + weaponSlot  // 48 is '0', so 49='1', 50='2', etc
                    handle(keyCode, "\(weaponSlot)", "Digit\(weaponSlot)")
                    
                    // Increment and wrap around
                    weaponSlot += 1
                    if weaponSlot > 7 {
                        weaponSlot = 1
                    }
                }
        case .x, .select, .menu:
            if pressed { DispatchQueue.main.async { [weak self] in self?.dismiss?() } }
        default:
            break
        }
    }
    
    func controllerDidMoveJoystick(side: JoystickSide, x: Float, y: Float) {
        guard side == .right else { return }
        
        let deadzone: Float = 0.1
        currentJoystickX = abs(x) < deadzone ? 0 : x
        currentJoystickY = abs(y) < deadzone ? 0 : y
        
        // Start timer if joystick is active and timer isn't running
        if (currentJoystickX != 0 || currentJoystickY != 0) && joystickTimer == nil {
            joystickTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
                self?.updateMouseFromJoystick()
            }
        }
        // Stop timer if joystick is neutral
        else if currentJoystickX == 0 && currentJoystickY == 0 {
            joystickTimer?.invalidate()
            joystickTimer = nil
        }
    }
    private func updateMouseFromJoystick() {
        guard currentJoystickX != 0 || currentJoystickY != 0 else { return }
        
        let sensitivity: CGFloat = 3
        let deltaX = CGFloat(currentJoystickX) * sensitivity
        let deltaY = -CGFloat(currentJoystickY) * sensitivity
        
        canvasCenterX += deltaX
        canvasCenterY += deltaY
        
        // Clamp to canvas bounds
        canvasCenterX = max(0, min(400, canvasCenterX))
        canvasCenterY = max(0, min(400, canvasCenterY))
        
        simulateAbsoluteMouseMove(x: canvasCenterX, y: canvasCenterY)
    }
    private func simulateAbsoluteMouseMove(x: CGFloat, y: CGFloat) {
        injectJS("""
        var canvas = document.getElementById('canvas');
        if (canvas) {
            var rect = canvas.getBoundingClientRect();
            var e = new MouseEvent('mousemove', {
                clientX: rect.left + \(x),
                clientY: rect.top + \(y),
                bubbles: true,
                cancelable: true,
                view: window
            });
            canvas.dispatchEvent(e);
            document.dispatchEvent(e);
        }
        """)
    }
    private func simulateMouseMove(x: CGFloat, y: CGFloat) {
        injectJS("""
        var canvas = document.getElementById('canvas');
        if (canvas) {
            var rect = canvas.getBoundingClientRect();
            var e = new MouseEvent('mousemove', {
                clientX: \(x),
                clientY: \(y),
                bubbles: true,
                cancelable: true
            });
            canvas.dispatchEvent(e);
            document.dispatchEvent(e);
        }
        """)
    }
    
    private func simulateMouseClick(pressed: Bool) {
        if pressed && !isMouseDown {
            isMouseDown = true
            injectJS("""
            var canvas = document.getElementById('canvas');
            if (canvas) {
                var e = new MouseEvent('mousedown', {
                    clientX: \(mouseX),
                    clientY: \(mouseY),
                    button: 0,
                    bubbles: true,
                    cancelable: true
                });
                canvas.dispatchEvent(e);
                document.dispatchEvent(e);
            }
            """)
        } else if !pressed && isMouseDown {
            isMouseDown = false
            injectJS("""
            var canvas = document.getElementById('canvas');
            if (canvas) {
                var e = new MouseEvent('mouseup', {
                    clientX: \(mouseX),
                    clientY: \(mouseY),
                    button: 0,
                    bubbles: true,
                    cancelable: true
                });
                canvas.dispatchEvent(e);
                document.dispatchEvent(e);
            }
            """)
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
    
    func configureCanvas() {
        injectJS("""
        var canvas = document.getElementById('canvas');
        if (canvas) {
            canvas.style.height = '440px';
            canvas.style.width = '100vw';
        }
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
