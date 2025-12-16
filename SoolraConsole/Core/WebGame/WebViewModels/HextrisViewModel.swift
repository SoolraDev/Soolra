import Foundation
import WebKit

final class HextrisViewModel: ObservableObject, WebGameViewModel, ControllerServiceDelegate {
    let startURL: URL
    weak var webView: WKWebView?
    private var keyState = Set<Int>()
    private var needsStart = true     // stay in "press start" mode until success
    var dismiss: (() -> Void)?
    @Published var needsAudioActivation = true
        
        func activateAudio() {
            injectJS("""
            // Try to play all loaded sounds
            for (var id in bkcore.Audio.sounds) {
                var sound = bkcore.Audio.sounds[id];
                if (sound.play) {
                    sound.play().catch(e => console.log('Audio play failed:', e));
                }
            }
            """)
            needsAudioActivation = false
        }
    init(startURL: URL) { self.startURL = startURL }

    func controllerDidPress(action: SoolraControllerAction, pressed: Bool) {
        func handle(_ which: Int, _ key: String, _ code: String) {
            pressed ? keyDown(which: which, key: key, codeName: code)
                    : keyUp(which: which, key: key, codeName: code)
        }

        // Helper: on A/B/Start/Y press, try Restart → Start, else fall back
        func consumeStartOrRestart(onConsumed: @escaping () -> Void, onNotConsumed: @escaping () -> Void) {
            guard pressed else { onNotConsumed(); return }
            pressRestart { restarted in
                if restarted {
                    self.needsStart = false
                    onConsumed()
                } else if self.needsStart {
                    self.pressStart { started in
                        if started { self.needsStart = false; onConsumed() } else { onNotConsumed() }
                    }
                } else {
                    onNotConsumed()
                }
            }
        }

        switch action {
        case .left:
            handle(37, "ArrowLeft", "ArrowLeft")

        case .y: // Left normally, but try Restart/Start first when applicable
            consumeStartOrRestart(onConsumed: {}, onNotConsumed: {
                handle(37, "ArrowLeft", "ArrowLeft")
            })

        case .right, .a: // A normally Right
            consumeStartOrRestart(onConsumed: {}, onNotConsumed: {
                handle(39, "ArrowRight", "ArrowRight")
            })

        case .down, .b: // B normally Down
            consumeStartOrRestart(onConsumed: {}, onNotConsumed: {
                handle(40, "ArrowDown", "ArrowDown")
            })

        case .start:
            if pressed {
                consumeStartOrRestart(onConsumed: {}, onNotConsumed: { /* no fallback */ })
            }

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
        (function(){
          function fire(t){
            var e=new KeyboardEvent('\(type)',{key:'\(key)',code:'\(codeName)',bubbles:true,cancelable:true});
            try{Object.defineProperty(e,'keyCode',{get:()=>\(which)});}catch(_){}
            try{Object.defineProperty(e,'which',{get:()=>\(which)});}catch(_){}
            try{t.dispatchEvent(e);}catch(_){}
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

    // MARK: - Start overlay (Play)
    private func pressStart(_ completion: ((Bool)->Void)? = nil) {
        injectJS(#"""
        (function(){
          function visible(el){ if(!el) return false;
            const s=getComputedStyle(el);
            if(s.display==='none'||s.visibility==='hidden'||+s.opacity===0) return false;
            const r=el.getBoundingClientRect(); return r.width>0 && r.height>0;
          }
          function centerRect(el){ const r=el.getBoundingClientRect(); return {x:r.left+r.width/2, y:r.top+r.height/2}; }
          function click(el,x,y){
            try{ el.focus(); }catch(_){}
            try{ el.dispatchEvent(new PointerEvent('pointerdown',{bubbles:true,cancelable:true,clientX:x,clientY:y,pointerType:'mouse',buttons:1})); }catch(_){}
            el.dispatchEvent(new MouseEvent('mousedown',{bubbles:true,cancelable:true,clientX:x,clientY:y,buttons:1}));
            try{ el.dispatchEvent(new PointerEvent('pointerup',{bubbles:true,cancelable:true,clientX:x,clientY:y,pointerType:'mouse'})); }catch(_){}
            el.dispatchEvent(new MouseEvent('mouseup',{bubbles:true,cancelable:true,clientX:x,clientY:y}));
            try{ el.click(); }catch(_){}
          }
          const ids=['startBtndiv','startbtn','startBtn','start','play','playBtn','play-button','start-button'];
          for (const id of ids){
            const el=document.getElementById(id);
            if (visible(el)) { const p=centerRect(el); click(el,p.x,p.y); return true; }
          }
          const byText = Array.from(document.querySelectorAll('button,a,div,span,.btn,.button'))
                        .find(el=>visible(el) && /(^|\\s)play(\\s|$)/i.test(el.textContent||''));
          if (byText) { const p=centerRect(byText); click(byText,p.x,p.y); return true; }
          const c=document.querySelector('canvas'); if (visible(c)) { const p=centerRect(c); click(c,p.x,p.y); return true; }
          return false;
        })();
        """#, completion: { result, _ in completion?((result as? Bool) == true) })
    }

    // MARK: - Restart button (img#restart shown when game over)
    private func pressRestart(_ completion: ((Bool)->Void)? = nil) {
        injectJS(#"""
        (function(){
          function visible(el){ if(!el) return false;
            const s=getComputedStyle(el);
            if(s.display==='none'||s.visibility==='hidden'||+s.opacity===0) return false;
            const r=el.getBoundingClientRect(); return r.width>0 && r.height>0;
          }
          function centerRect(el){ const r=el.getBoundingClientRect(); return {x:r.left+r.width/2, y:r.top+r.height/2}; }
          function click(el,x,y){
            try{ el.focus(); }catch(_){}
            try{ el.dispatchEvent(new PointerEvent('pointerdown',{bubbles:true,cancelable:true,clientX:x,clientY:y,pointerType:'mouse',buttons:1})); }catch(_){}
            el.dispatchEvent(new MouseEvent('mousedown',{bubbles:true,cancelable:true,clientX:x,clientY:y,buttons:1}));
            try{ el.dispatchEvent(new PointerEvent('pointerup',{bubbles:true,cancelable:true,clientX:x,clientY:y,pointerType:'mouse'})); }catch(_){}
            el.dispatchEvent(new MouseEvent('mouseup',{bubbles:true,cancelable:true,clientX:x,clientY:y}));
            try{ el.click(); }catch(_){}
          }
          const img = document.getElementById('restart');
          if (visible(img)) {
            // Click the image or its closest clickable parent
            const clickable = img.closest('button, a, [role="button"]') || img;
            const p = centerRect(clickable);
            click(clickable, p.x, p.y);
            return true;
          }
          return false;
        })();
        """#, completion: { result, _ in completion?((result as? Bool) == true) })
    }

    // MARK: - JS bridge
    private func injectJS(_ js: String, completion: ((Any?, Error?) -> Void)? = nil) {
        DispatchQueue.main.async {
            guard let webView = self.webView else { completion?(nil, NSError(domain: "NoWebView", code: 0)); return }
            webView.evaluateJavaScript(js, completionHandler: completion)
        }
    }
}
