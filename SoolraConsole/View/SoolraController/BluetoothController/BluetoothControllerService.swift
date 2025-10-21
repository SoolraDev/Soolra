//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import Foundation
import GameController

protocol ControllerServiceDelegate: AnyObject {
    func controllerDidPress(action: SoolraControllerAction, pressed: Bool)
}

class BluetoothControllerService: ObservableObject {
    static let shared = BluetoothControllerService()
    @Published private(set) var isControllerConnected: Bool = false
    weak var delegate: ControllerServiceDelegate?
    
    // Separate state tracking for each stick
    private var leftStickDirection: SoolraControllerAction?
    private var rightStickDirection: SoolraControllerAction?
    private let inputThreshold: Float = 0.5
    private let deadzone: Float = 0.1
    private let stateLock = NSLock()

    private init() {
        setupControllerObservers()
        refreshConnectedState()
    }

    // MARK: - Setup

    private func setupControllerObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDidConnect),
            name: .GCControllerDidConnect,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(controllerDidDisconnect),
            name: .GCControllerDidDisconnect,
            object: nil
        )
    }

    @objc private func controllerDidConnect(notification: Notification) {
        if let controller = notification.object as? GCController {
            logControllerButtons(controller)
            setupControllerInput(controller: controller)
        }

        if let controller = notification.object as? GCController {
            setupControllerInput(controller: controller)
            print("🎮 Controller connected")
        }
        refreshConnectedState()
    }

    @objc private func controllerDidDisconnect(notification: Notification) {
        print("🎮 Controller disconnected")
        clearAllInputs()
        refreshConnectedState()
    }
    
    private func clearAllInputs() {
        stateLock.lock()
        defer { stateLock.unlock() }
        
        if let direction = leftStickDirection {
            delegate?.controllerDidPress(action: direction, pressed: false)
            leftStickDirection = nil
        }
        if let direction = rightStickDirection {
            delegate?.controllerDidPress(action: direction, pressed: false)
            rightStickDirection = nil
        }
    }

    private func logControllerButtons(_ controller: GCController) {
        guard let gamepad = controller.extendedGamepad else {
            print("❌ No extended gamepad profile for \(controller.vendorName ?? "unknown")")
            return
        }

        print("🎮 Controller connected: \(controller.vendorName ?? "Unknown")")
        print("Product category: \(controller.productCategory)")
        print("--------------------------------------------")

        // Standard buttons
        let standardButtons: [(String, GCControllerButtonInput?)] = [
            ("A", gamepad.buttonA),
            ("B", gamepad.buttonB),
            ("X", gamepad.buttonX),
            ("Y", gamepad.buttonY),
            ("L1", gamepad.leftShoulder),
            ("R1", gamepad.rightShoulder),
            ("L2", gamepad.leftTrigger),
            ("R2", gamepad.rightTrigger),
            ("Menu / Start", gamepad.buttonMenu),
            ("Options / Select", gamepad.buttonOptions),
            ("Home / Guide", gamepad.buttonHome),
        ]

        for (name, button) in standardButtons where button != nil {
            print("✅ \(name)")
        }

        // Try to find *any* extra buttons (works iOS 15+)
        if #available(iOS 15.0, *) {
            let knownSet = Set(standardButtons.compactMap { $0.1 })
            let all = gamepad.allButtons
            let extras = all.filter { !knownSet.contains($0) }
            print("Extra buttons found: \(extras.count)")
            for (i, b) in extras.enumerated() {
                print("🔹 Extra button \(i): \(b)")
            }
        } else {
            print("⚠️ allButtons API unavailable (requires iOS 15+).")
        }

        print("--------------------------------------------")
    }


    
    
    private func setupControllerInput(controller: GCController) {
        guard let gamepad = controller.extendedGamepad else { return }
        DispatchQueue.main.async {
            gamepad.buttonHome?.preferredSystemGestureState = .disabled
            gamepad.buttonMenu.preferredSystemGestureState = .disabled
            gamepad.buttonOptions?.preferredSystemGestureState = .disabled

        }
        // Button handlers
        gamepad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            print("🟢 [RAW] A button pressed=\(pressed) at \(Date())")
            self?.delegate?.controllerDidPress(action: .a, pressed: pressed)
        }
        gamepad.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.delegate?.controllerDidPress(action: .b, pressed: pressed)
        }
        gamepad.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.delegate?.controllerDidPress(action: .x, pressed: pressed)
        }
        gamepad.buttonY.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.delegate?.controllerDidPress(action: .y, pressed: pressed)
        }
        gamepad.leftShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.delegate?.controllerDidPress(action: .l, pressed: pressed)
        }
        gamepad.rightShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.delegate?.controllerDidPress(action: .r, pressed: pressed)
        }

        // D-pad handlers
        gamepad.dpad.up.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.delegate?.controllerDidPress(action: .up, pressed: pressed)
        }
        gamepad.dpad.down.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.delegate?.controllerDidPress(action: .down, pressed: pressed)
        }
        gamepad.dpad.left.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.delegate?.controllerDidPress(action: .left, pressed: pressed)
        }
        gamepad.dpad.right.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.delegate?.controllerDidPress(action: .right, pressed: pressed)
        }

        // System buttons
        gamepad.buttonOptions?.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.delegate?.controllerDidPress(action: .select, pressed: pressed)
        }
            
        gamepad.buttonHome?.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.delegate?.controllerDidPress(action: .menu, pressed: pressed)
        }
        gamepad.buttonHome?.preferredSystemGestureState = .disabled
        
        gamepad.buttonMenu.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.delegate?.controllerDidPress(action: .start, pressed: pressed)
        }

        // Analog sticks
        gamepad.leftThumbstick.valueChangedHandler = { [weak self] _, xAxis, yAxis in
            self?.handleStickInput(xAxis: xAxis, yAxis: yAxis, isLeftStick: true)
        }

        gamepad.rightThumbstick.valueChangedHandler = { [weak self] _, xAxis, yAxis in
            self?.handleStickInput(xAxis: xAxis, yAxis: yAxis, isLeftStick: false)
        }
    }

    private func handleStickInput(xAxis: Float, yAxis: Float, isLeftStick: Bool) {
        stateLock.lock()
        defer { stateLock.unlock() }
        
        let currentDirection = isLeftStick ? leftStickDirection : rightStickDirection
        let newDirection = determineStickDirection(xAxis: xAxis, yAxis: yAxis)
        
        // Only process if direction actually changed
        if newDirection != currentDirection {
            // Release old direction if it exists
            if let current = currentDirection {
                delegate?.controllerDidPress(action: current, pressed: false)
            }
            
            // Press new direction if it exists
            if let new = newDirection {
                delegate?.controllerDidPress(action: new, pressed: true)
            }
            
            // Update state
            if isLeftStick {
                leftStickDirection = newDirection
            } else {
                rightStickDirection = newDirection
            }
        }
    }

    private func determineStickDirection(xAxis: Float, yAxis: Float) -> SoolraControllerAction? {
        // Apply deadzone
        let x = abs(xAxis) < deadzone ? 0 : xAxis
        let y = abs(yAxis) < deadzone ? 0 : yAxis
        
        // If both axes are below threshold, return nil (neutral position)
        if abs(x) < inputThreshold && abs(y) < inputThreshold {
            return nil
        }
        
        // Determine primary direction based on larger axis
        if abs(x) > abs(y) {
            return x > 0 ? .right : .left
        } else {
            return y > 0 ? .up : .down
        }
    }
    
    private func refreshConnectedState() {
        DispatchQueue.main.async {
            self.isControllerConnected = !GCController.controllers().isEmpty
        }
    }
    
}
