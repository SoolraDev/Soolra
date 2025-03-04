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

class BluetoothControllerService {
    static let shared = BluetoothControllerService()
    weak var delegate: ControllerServiceDelegate?
    
    // Separate state tracking for each stick
    private var leftStickDirection: SoolraControllerAction?
    private var rightStickDirection: SoolraControllerAction?
    private let inputThreshold: Float = 0.5
    private let deadzone: Float = 0.1
    private let stateLock = NSLock()

    private init() {
        setupControllerObservers()
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
            setupControllerInput(controller: controller)
            print("🎮 Controller connected")
        }
    }

    @objc private func controllerDidDisconnect(notification: Notification) {
        print("🎮 Controller disconnected")
        clearAllInputs()
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

    private func setupControllerInput(controller: GCController) {
        guard let gamepad = controller.extendedGamepad else { return }

        // Button handlers
        gamepad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
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
}
