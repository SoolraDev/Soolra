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
            rotationDirection = pressed ? -1 : (rotationDirection == -1 ? 0 : rotationDirection)
            pressed ? startMovementRotation() : stopMovementIfIdle()

        case .right:
            rotationDirection = pressed ? 1 : (rotationDirection == 1 ? 0 : rotationDirection)
            pressed ? startMovementRotation() : stopMovementIfIdle()

        case .a:
        
            pressCraftyActionKey()
            if pressed {
                if !isGameStarted {
                    pressPlayButtonViaClick()
                } else {
                    simulateDoubleTapAndHold()
                }
            } else {
                if isGameStarted {
                    releaseHeldTouch()
                }
            }


        case .b:
                    if pressed {
                        print("⬅️ B pressed — dismissing view")
                        dismiss?()
                    }
                default:
            break
        }
    }
    private func logPlayButtonCoordinates() {
        injectJS("""
            (function() {
                var el = document.getElementById("playh");
                if (!el) return "Not found";

                var rect = el.getBoundingClientRect();
                return {
                    x: Math.round(rect.left + rect.width / 2),
                    y: Math.round(rect.top + rect.height / 2)
                };
            })();
        """) { result, error in
            if let error = error {
                print("❌ Failed to get button position: \(error.localizedDescription)")
            } else if let pos = result as? [String: Any] {
                print("✅ Play button center: x=\(pos["x"] ?? "?"), y=\(pos["y"] ?? "?")")
            } else {
                print("⚠️ Play button not found or no coordinates returned")
            }
        }
    }
    
    func pressPlayButtonViaClick() {
        let js = """
        (function() {
            var btn = document.getElementById("playh");
            if (!btn) return "not-found";

            // Force reflow in case it's offscreen
            btn.scrollIntoView({ block: 'center' });

            // Trigger click directly
            btn.click();

            return "clicked";
        })();
        """

        injectJS(js) { result, error in
            if let error = error {
                print("❌ JS error:", error.localizedDescription)
            } else if let status = result as? String {
                switch status {
                case "clicked":
                    print("✅ Play button was clicked programmatically")
                    self.isGameStarted = true
                case "not-found":
                    print("⚠️ Play button not found in DOM")
                default:
                    print("⚠️ Unexpected result:", status)
                }
            }
        }
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

    private func pressCraftyActionKey() {
        fitCanvasToWebViewFill()
        let js = """
        (function () {
          function fireKey(target, type, keyStr, codeStr, keyCodeNum) {
            try {
              var evt = new KeyboardEvent(type, {
                key: keyStr || '',
                code: codeStr || '',
                keyCode: keyCodeNum || 0,
                which: keyCodeNum || 0,
                bubbles: true,
                cancelable: true
              });
              // Some engines ignore keyCode/which in init; force assign
              Object.defineProperty(evt, 'keyCode', { get: function(){ return keyCodeNum || 0; }});
              Object.defineProperty(evt, 'which',   { get: function(){ return keyCodeNum || 0; }});
              (target || window).dispatchEvent(evt);
            } catch (_) {}
          }

          function kdkuEverywhere(keyStr, codeStr, keyCodeNum) {
            var targets = [
              window,
              document,
              document.body,
              (window.Crafty && Crafty.stage && Crafty.stage.elem) || null
            ].filter(Boolean);

            targets.forEach(function(t){
              fireKey(t, 'keydown', keyStr, codeStr, keyCodeNum);
            });

            setTimeout(function(){
              targets.forEach(function(t){
                fireKey(t, 'keyup', keyStr, codeStr, keyCodeNum);
              });
            }, 40);
          }

          function triggerCraftyBoth(keyStr, keyNum) {
            if (!window.Crafty) return;
            try {
              // Crafty entities listen for 'KeyDown'/'KeyUp' with e.key
              Crafty.trigger('KeyDown', { key: keyStr });
              Crafty.trigger('KeyUp',   { key: keyStr });
            } catch (_){}
            try {
              Crafty.trigger('KeyDown', { key: keyNum });
              Crafty.trigger('KeyUp',   { key: keyNum });
            } catch (_){}
          }

          function pressAction() {
            // Focus the stage so Crafty is “active”
            try { Crafty && Crafty.stage && Crafty.stage.elem && Crafty.stage.elem.focus(); } catch(_){}

            // Prefer the game’s configured action keys if present
            var actions = (window.Player && Player.keys && Player.keys.keyAction) ? Player.keys.keyAction.slice() : null;

            if (actions && actions.length) {
              actions.forEach(function(k) {
                if (typeof k === 'number') {
                  // numeric keycodes
                  if (k === 13) { kdkuEverywhere('Enter','Enter',13); triggerCraftyBoth('Enter',13); }
                  else if (k === 32) { kdkuEverywhere(' ','Space',32); triggerCraftyBoth(' ',32); }
                  else { kdkuEverywhere('', '', k); triggerCraftyBoth('', k); }
                } else if (typeof k === 'string') {
                  var s = k.replace(/\\u00A0/g,' ').trim().toLowerCase();
                  if (s.includes('enter')) { kdkuEverywhere('Enter','Enter',13); triggerCraftyBoth('Enter',13); }
                  else if (s.includes('space') || s === ' ') { kdkuEverywhere(' ','Space',32); triggerCraftyBoth(' ',32); }
                  else { kdkuEverywhere(k,k,0); triggerCraftyBoth(k,0); }
                }
              });
            } else {
              // Fallback: Enter then Space
              kdkuEverywhere('Enter','Enter',13); triggerCraftyBoth('Enter',13);
              setTimeout(function(){ kdkuEverywhere(' ','Space',32); triggerCraftyBoth(' ',32); }, 60);
            }

            return true;
          }

          return pressAction();
        })();
        """
        injectJS(js)
    }

    
    
    private func simulateDoubleTapAndHold() {
        guard let angle = Optional(movementAngle) else {
            print("⚠️ No direction angle set — can't boost")
            return
        }

        let id = Int(Date().timeIntervalSince1970 * 1000)
        activeTouchID = id

        let x = movementCenterX + cos(angle) * movementRadius
        let y = movementCenterY + sin(angle) * movementRadius

        print("⚡️ Boost (double-tap + hold) at (\(x), \(y))")

        let js = """
        (function() {
            function fireTouch(x, y, type, id) {
                const touchObj = new Touch({
                    identifier: id,
                    target: document.elementFromPoint(x, y),
                    clientX: x,
                    clientY: y,
                    radiusX: 3,
                    radiusY: 3,
                    rotationAngle: 0,
                    force: 1
                });

                const event = new TouchEvent(type, {
                    cancelable: true,
                    bubbles: true,
                    touches: type === 'touchend' ? [] : [touchObj],
                    targetTouches: type === 'touchend' ? [] : [touchObj],
                    changedTouches: [touchObj]
                });

                document.dispatchEvent(event);
            }

            const id = \(id);
            const x = \(Int(x));
            const y = \(Int(y));

            fireTouch(x, y, 'touchstart', id);
            fireTouch(x, y, 'touchend', id);

            setTimeout(function() {
                fireTouch(x, y, 'touchstart', id);
            }, 100);
        })();
        """

        injectJS(js)
    }

    private func releaseHeldTouch() {
        guard let id = activeTouchID else {
            print("⚠️ No active boost touch to release")
            return
        }

        let x = movementCenterX + cos(movementAngle) * movementRadius
        let y = movementCenterY + sin(movementAngle) * movementRadius

        print("🛑 Releasing boost touch at (\(x), \(y))")

        let js = """
        (function() {
            const id = \(id);
            const x = \(Int(x));
            const y = \(Int(y));

            const touchObj = new Touch({
                identifier: id,
                target: document.elementFromPoint(x, y),
                clientX: x,
                clientY: y,
                radiusX: 3,
                radiusY: 3,
                force: 0.5,
                rotationAngle: 0
            });

            const event = new TouchEvent('touchend', {
                bubbles: true,
                cancelable: true,
                touches: [],
                targetTouches: [],
                changedTouches: [touchObj]
            });

            document.dispatchEvent(event);
        })();
        """

        activeTouchID = nil
        injectJS(js)
    }

    
    private func startMovementRotation() {
        guard movementTimer == nil else { return }

        if movementTouchID == nil {
            movementTouchID = Int(Date().timeIntervalSince1970 * 1000)
            beginMovementTouch()
        }

        movementTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.updateMovementAngle()
        }
    }

    private func stopMovementIfIdle() {
        if rotationDirection == 0 {
            movementTimer?.invalidate()
            movementTimer = nil
            endMovementTouch()
        }
    }
    private func updateMovementAngle() {
        guard let id = movementTouchID else { return }

        let angleDelta = 2.0 * Double.pi / 180.0  // 2 degrees per frame
        movementAngle += Double(rotationDirection) * angleDelta

        // Normalize angle between 0 and 2π
        if movementAngle < 0 { movementAngle += 2 * .pi }
        if movementAngle >= 2 * .pi { movementAngle -= 2 * .pi }

        let x = movementCenterX + cos(movementAngle) * movementRadius
        let y = movementCenterY + sin(movementAngle) * movementRadius

        let js = """
        (function() {
            const id = \(id);
            const touchObj = new Touch({
                identifier: id,
                target: document.elementFromPoint(\(Int(x)), \(Int(y))),
                clientX: \(Int(x)),
                clientY: \(Int(y)),
                radiusX: 3, radiusY: 3, force: 1, rotationAngle: 0
            });

            const event = new TouchEvent('touchmove', {
                bubbles: true,
                cancelable: true,
                touches: [touchObj],
                targetTouches: [touchObj],
                changedTouches: [touchObj]
            });

            document.dispatchEvent(event);
        })();
        """
        injectJS(js)
    }
    private func beginMovementTouch() {
        let id = movementTouchID!
        let x = movementCenterX + cos(movementAngle) * movementRadius
        let y = movementCenterY + sin(movementAngle) * movementRadius

        let js = """
        (function() {
            const id = \(id);
            const touchObj = new Touch({
                identifier: id,
                target: document.elementFromPoint(\(Int(x)), \(Int(y))),
                clientX: \(Int(x)),
                clientY: \(Int(y)),
                radiusX: 3, radiusY: 3, force: 1, rotationAngle: 0
            });

            const event = new TouchEvent('touchstart', {
                bubbles: true,
                cancelable: true,
                touches: [touchObj],
                targetTouches: [touchObj],
                changedTouches: [touchObj]
            });

            document.dispatchEvent(event);
        })();
        """
        injectJS(js)
    }

    private func endMovementTouch() {
        guard let id = movementTouchID else { return }

        let js = """
        (function() {
            const id = \(id);
            const touchObj = new Touch({
                identifier: id,
                target: document.elementFromPoint(\(Int(movementCenterX)), \(Int(movementCenterY))),
                clientX: \(Int(movementCenterX)),
                clientY: \(Int(movementCenterY)),
                radiusX: 3, radiusY: 3, force: 0.5, rotationAngle: 0
            });

            const event = new TouchEvent('touchend', {
                bubbles: true,
                cancelable: true,
                touches: [],
                targetTouches: [],
                changedTouches: [touchObj]
            });

            document.dispatchEvent(event);
        })();
        """

        movementTouchID = nil
        injectJS(js)
    }

    private func fitCanvasToWebViewFill() {
        let js = """
        (function() {
          // Ensure responsive viewport inside the WKWebView
          (function ensureViewport() {
            if (!document.querySelector('meta[name=viewport]')) {
              var m = document.createElement('meta');
              m.name = 'viewport';
              m.content = 'width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no';
              document.head.appendChild(m);
            }
          })();

          // Make page use the whole WKWebView area
          document.documentElement.style.height = '100%';
          document.body.style.height = '100%';
          document.documentElement.style.margin = '0';
          document.body.style.margin = '0';
          document.body.style.overflow = 'hidden';

          // Pick the largest canvas on the page (Crafty/WebGL games often have 1)
          var canvases = Array.from(document.querySelectorAll('canvas'));
          if (!canvases.length) return 'no-canvas';
          var canvas = canvases.sort(function(a,b){
            return (b.width*b.height) - (a.width*a.height);
          })[0];

          // Fill the WKWebView (which is half the iPhone screen in your layout)
          canvas.style.display = 'block';
          canvas.style.width = '100vw';
          canvas.style.height = '100vh';
          canvas.style.maxWidth = '100vw';
          canvas.style.maxHeight = '100vh';
          canvas.style.margin = '0 auto';
          canvas.style.imageRendering = 'auto'; // or 'pixelated' if you prefer chunky pixels

          // Some engines listen for resize — nudge them
          window.dispatchEvent(new Event('resize'));

          return { cssWidth: canvas.style.width, cssHeight: canvas.style.height, backing: [canvas.width, canvas.height] };
        })();
        """
        injectJS(js)
    }
    private func fitCanvasToWebViewLetterbox() {
        let js = """
        (function() {
          document.documentElement.style.height = '100%';
          document.body.style.height = '100%';
          document.documentElement.style.margin = '0';
          document.body.style.margin = '0';
          document.body.style.overflow = 'hidden';

          var canvases = Array.from(document.querySelectorAll('canvas'));
          if (!canvases.length) return 'no-canvas';
          var canvas = canvases.sort((a,b)=>(b.width*b.height)-(a.width*a.height))[0];

          var vw = window.innerWidth, vh = window.innerHeight;
          var cw = canvas.width, ch = canvas.height;
          if (!cw || !ch) { cw = canvas.getBoundingClientRect().width || vw; ch = canvas.getBoundingClientRect().height || vh; }

          var sx = vw / cw, sy = vh / ch;
          var scale = Math.min(sx, sy);

          // Wrap in a container to center it
          var wrapper = canvas.parentElement;
          if (!wrapper || wrapper === document.body || wrapper === document.documentElement) {
            wrapper = document.body;
          }
          wrapper.style.position = 'relative';
          wrapper.style.width = '100vw';
          wrapper.style.height = '100vh';
          wrapper.style.margin = '0';
          wrapper.style.backgroundColor = '#000';

          canvas.style.transformOrigin = 'top left';
          canvas.style.transform = 'scale(' + scale + ')';
          // center it
          var left = (vw - cw * scale) / 2;
          var top  = (vh - ch * scale) / 2;
          canvas.style.position = 'absolute';
          canvas.style.left = left + 'px';
          canvas.style.top  = top  + 'px';

          // Optional: make pointer coords map correctly when using transform
          // Many engines already use clientX/clientY, which is fine; otherwise you may need to translate.

          window.dispatchEvent(new Event('resize'));
          return {vw:vw, vh:vh, cw:cw, ch:ch, scale:scale};
        })();
        """
        injectJS(js)
    }


}
