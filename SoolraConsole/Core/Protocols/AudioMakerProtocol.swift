//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import Foundation

public protocol AudioMakerProtocol {
    func play()
    func pause()
    func stop()
    func reset()
    func queueBuffer(_ buffer: UnsafePointer<UInt16>, size: Int)
}
