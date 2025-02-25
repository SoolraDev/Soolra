//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import SwiftUI

struct JoystickView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var consoleManager: ConsoleCoreManager
    @State var position: CGPoint?

    private let r1 = 60.0
    private let r2 = 50.0
    
    var onButtonPress: ((SoolraControllerAction) -> Void)?

    var body: some View {
        GeometryReader { geometry in
            let rect = geometry.frame(in: .local)
            let center = CGPoint(x: rect.origin.x + rect.width / 2, y: rect.origin.y + rect.height / 2)

            Group {
                //Outer gradient circle
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(stops: themeManager.keyboardColor.joystickGradientColors),
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 6
                    )
                    .frame(width: r1 * 2, height: r1 * 2)
                    .position(center)

                //Inner circle
                Circle()
                    .fill(Color.clear)
                    .frame(width: r1 * 2, height: r1 * 2)
                    .position(center)

                //Joystick
                Image("controller-stick")
                    .resizable()
                    .frame(width: r2 * 2, height: r2 * 2)
                    .position(position ?? center)
                    .opacity(1)
            }.gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged({ value in
                        moveTo(value.location, center)
                    })
                    .onEnded({ _ in
                        position = center
                        releaseAllKey()
                    })
            )
        }
        .frame(width: r1 * 2, height: r1 * 2)
    }

    @State private var lastActionTime: Date?

    private func moveTo(_ newPosition: CGPoint, _ center: CGPoint) {
        var newPosition = newPosition

        let distance = newPosition.distanceTo(center)
        let theta = getAngle(newPosition, center, distance)
        let angle = theta / Double.pi * 180

        if distance > r1 {
            newPosition.x = center.x + r1 * cos(theta)
            newPosition.y = center.y + r1 * sin(theta)
        }
        position = newPosition
        // This part handles actions to be passed for the home screen
        let newAngle = angle + 180.0
        if distance > 30 {
            let now = Date()
            guard lastActionTime == nil || now.timeIntervalSince(lastActionTime!) >= 0.5 else {
                return
            }

            self.lastActionTime = now
            if (newAngle >= 315 && newAngle < 360) || (newAngle >= 0 && newAngle < 45) { // Left
                onButtonPress?(.left)
            } else if newAngle >= 45 && newAngle < 135 { // Up
                onButtonPress?(.up)
            } else if newAngle >= 135 && newAngle < 225 { // Right
                onButtonPress?(.right)
            } else if newAngle >= 225 && newAngle < 315 { // Down
                onButtonPress?(.down)
            }
        }

        setKey(withAngle: newAngle)
    }

    private func getAngle(_ newPosition: CGPoint, _ center: CGPoint, _ distance: Double) -> Double {
        let oa = (1.0, 0.0)
        let ob = (newPosition.x - center.x, newPosition.y - center.y)
        var theta = acos((oa.0 * ob.0 + oa.1 * ob.1) / distance)

        if oa.0 * ob.1 - oa.1 * ob.0 < 0 {
            theta = -theta
        }

        return theta
    }

    private func setKey(withAngle angle: Double) {
        var mask: UInt8 = 0

        if angle >= 22.5 && angle < 67.5 {
            mask |= 1 << 6
            mask |= 1 << 4
        } else if angle >= 67.5 && angle < 112.5 {
            mask |= 1 << 4
        } else if angle >= 112.5 && angle < 157.5 {
            mask |= 1 << 4
            mask |= 1 << 7
        } else if angle >= 157.5 && angle < 202.5 {
            mask |= 1 << 7
        } else if angle >= 202.5 && angle < 247.5 {
            mask |= 1 << 7
            mask |= 1 << 5
        } else if angle >= 247.5 && angle < 292.5 {
            mask |= 1 << 5
        } else if angle >= 292.5 && angle < 337.5 {
            mask |= 1 << 6
            mask |= 1 << 5
        } else {
            mask |= 1 << 6
        }

        
        setKey(withMask: mask)
        
    }

    private func setKey(withMask mask: UInt8) {
        // Map bits to controller actions
        let actionMap: [(bit: Int, action: SoolraControllerAction)] = [
            (4, .up),
            (5, .down),
            (6, .left),
            (7, .right)
        ]
        
        for (bit, action) in actionMap {
            let isPressed = (mask >> bit) & 1 == 1
            consoleManager.handleControllerAction(action, pressed: isPressed)
        }
    }

    private func releaseAllKey() {
        setKey(withMask: 0)
    }
}

struct JoystickView_Previews: PreviewProvider {
    static var previews: some View {
        JoystickView()
         
            .environmentObject(ThemeManager()) // Provide the theme manager
            }
        }
