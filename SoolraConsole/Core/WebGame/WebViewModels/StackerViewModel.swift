import Foundation
import WebKit

final class StackerViewModel: ObservableObject, WebGameViewModel, ControllerServiceDelegate {
    let startURL: URL
    weak var webView: WKWebView?
    private var keyState = Set<Int>()
    var dismiss: (() -> Void)?

    init(startURL: URL) { self.startURL = startURL }

    func controllerDidPress(action: SoolraControllerAction, pressed: Bool) {
        func handle(_ which: Int, _ key: String, _ code: String) {
            pressed ? keyDown(which: which, key: key, codeName: code)
                    : keyUp(which: which, key: key, codeName: code)
        }

        // A/B/Y/Start: try buttons, else screen tap
        func confirmOrTap() { if pressed { pressSpecialButtonsOrTap() } }

        switch action {
        case .left:
            handle(37, "ArrowLeft", "ArrowLeft")
        case .right:
            handle(39, "ArrowRight", "ArrowRight")
        case .down:
            handle(40, "ArrowDown", "ArrowDown")

        case .a, .b, .y, .start:
            confirmOrTap()

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
        (function(){
          function fire(t){
            var e=new KeyboardEvent('\(type)',{key:'\(key)',code:'\(codeName)',bubbles:true,cancelable:true});
            try{Object.defineProperty(e,'keyCode',{get:()=>\(which)});}catch(_){}
            try{Object.defineProperty(e,'which',{get:()=>\(which)});}catch(_){}
            t.dispatchEvent(e);
          }
          var c=document.querySelector('canvas');
          if(c){ c.setAttribute('tabindex','0'); try{c.focus();}catch(_){} }
          if(!document.activeElement || document.activeElement===document.body){
            try{document.body.setAttribute('tabindex','0'); document.body.focus();}catch(_){}
          }
          fire(document); fire(window); if(document.body) fire(document.body); if(c) fire(c);
        })();
        """)
    }

//    // MARK: - Prefer reload, then start; else tap screen (pointer+touch+mouse)
//    private func pressSpecialButtonsOrTap() {
//        injectJS(#"""
//        (function(){
//          function visible(el){
//            if(!el) return false;
//            const s=getComputedStyle(el);
//            if(s.display==='none'||s.visibility==='hidden'||+s.opacity===0) return false;
//            const r=el.getBoundingClientRect(); return r.width>0 && r.height>0;
//          }
//          function centerRect(el){ const r=el.getBoundingClientRect(); return {x:r.left+r.width/2, y:r.top+r.height/2}; }
//          function clickSequence(target, x, y){
//            try{ target.focus(); }catch(_){}
//
//            // Pointer events
//            try{ target.dispatchEvent(new PointerEvent('pointerdown',{bubbles:true,cancelable:true,clientX:x,clientY:y,pointerType:'touch',buttons:1})); }catch(_){}
//            try{ target.dispatchEvent(new PointerEvent('pointerup',{bubbles:true,cancelable:true,clientX:x,clientY:y,pointerType:'touch'})); }catch(_){}
//
//            // Touch events (for engines that only listen to touch)
//            try{
//              const touchInit={identifier:Date.now(), target:target, clientX:x, clientY:y, radiusX:1, radiusY:1, force:1};
//              const t = new Touch(touchInit);
//              const touches = new TouchList(t);
//              const none = new TouchList();
//              target.dispatchEvent(new TouchEvent('touchstart',{bubbles:true,cancelable:true,touches,changedTouches:touches,targetTouches:touches}));
//              target.dispatchEvent(new TouchEvent('touchend',{bubbles:true,cancelable:true,touches:none,changedTouches:touches,targetTouches:none}));
//            }catch(_){}
//
//            // Mouse events (as fallback)
//            target.dispatchEvent(new MouseEvent('mousedown',{bubbles:true,cancelable:true,clientX:x,clientY:y,buttons:1}));
//            target.dispatchEvent(new MouseEvent('mouseup',{bubbles:true,cancelable:true,clientX:x,clientY:y}));
//            try{ target.click(); }catch(_){}
//          }
//          function clickCenter(el){ const p=centerRect(el); clickSequence(el, p.x, p.y); }
//
//          // Prefer the Game Over reload button first, then the start button
//          const selectors = ['.over-button-b.js-reload', '.start'];
//          for (const sel of selectors){
//            const el = Array.from(document.querySelectorAll(sel)).find(visible);
//            if (visible(el)) { clickCenter(el); return true; }
//          }
//
//          // Fallback: tap the game surface or center of viewport
//          const canvas = Array.from(document.querySelectorAll('canvas')).find(visible);
//          if (canvas) { clickCenter(canvas); return true; }
//
//          // Last resort: element under viewport center
//          const cx = Math.floor(window.innerWidth/2), cy = Math.floor(window.innerHeight/2);
//          const target = document.elementFromPoint(cx, cy) || document.body || document.documentElement;
//          clickSequence(target, cx, cy);
//          return true;
//        })();
//        """#)
//    }
    private func pressSpecialButtonsOrTap() {
        injectJS(#"""
        (function () {
          function isVisible(el) {
            if (!el) return false;
            const s = getComputedStyle(el);
            if (s.display === 'none' || s.visibility === 'hidden' || +s.opacity === 0) return false;
            const r = el.getBoundingClientRect();
            return r.width > 0 && r.height > 0;
          }

          function centerPoint(el) {
            const r = el.getBoundingClientRect();
            return { x: r.left + r.width / 2, y: r.top + r.height / 2 };
          }

          function fire(target, type, Ctor, init) {
            try { target.dispatchEvent(new Ctor(type, init)); } catch (_) {}
          }

          function interactAt(target, x, y) {
            const common = { bubbles: true, cancelable: true, clientX: x, clientY: y, view: window };

            // Pointer events first (covers mouse/touch/pen in modern browsers)
            if (window.PointerEvent) {
              fire(target, 'pointerdown', PointerEvent, { ...common, pointerId: 1, pointerType: 'mouse', isPrimary: true, buttons: 1 });
              fire(target, 'pointerup',   PointerEvent, { ...common, pointerId: 1, pointerType: 'mouse', isPrimary: true, buttons: 0 });
            }

            // Mouse events (many engines still rely on these)
            fire(target, 'mousedown', MouseEvent, { ...common, button: 0, buttons: 1 });
            fire(target, 'mouseup',   MouseEvent, { ...common, button: 0, buttons: 0 });
            fire(target, 'click',     MouseEvent, { ...common, button: 0, buttons: 0 });

            // Touch events (Zepto taps often hook into these)
            try {
              if ('ontouchstart' in window && typeof TouchEvent === 'function' && typeof Touch === 'function') {
                const t = new Touch({
                  identifier: Date.now(),
                  target,
                  clientX: x, clientY: y,
                  pageX: x + window.scrollX, pageY: y + window.scrollY,
                  screenX: x, screenY: y,
                  radiusX: 1, radiusY: 1, force: 1
                });
                const base = { bubbles: true, cancelable: true };
                fire(target, 'touchstart', TouchEvent, { ...base, touches: [t], targetTouches: [t], changedTouches: [t] });
                fire(target, 'touchend',   TouchEvent, { ...base, touches: [],   targetTouches: [],  changedTouches: [t] });
              }
            } catch (_) {}
          }

          function tapCenter(el) {
            if (!el) return;
            try { el.focus?.(); } catch (_) {}
            // Prefer the top-most element at the center point to respect overlays
            const { x, y } = centerPoint(el);
            const top = document.elementFromPoint(x, y) || el;
            try { top.click?.(); } catch (_) {}
            interactAt(top, x, y);
          }

          // 1) Game over -> reload button
          const reloadBtn = document.querySelector('.over-button-b.js-reload');
          if (isVisible(reloadBtn)) { tapCenter(reloadBtn); return; }

          // 2) Landing -> start button
          const startBtn = document.querySelector('.start');
          if (isVisible(startBtn)) { tapCenter(startBtn); return; }

          // 3) Canvas center (unhide #canvas if needed)
          const idCanvas = document.getElementById('canvas');
          if (idCanvas) idCanvas.classList.remove('hide');

          const canvas = [...document.querySelectorAll('canvas')].find(isVisible) || idCanvas;
          if (canvas) {
            tapCenter(canvas);
            return;
          }

          // 4) Fallback: document body center
          tapCenter(document.body || document.documentElement);
        })();
        """#)
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
