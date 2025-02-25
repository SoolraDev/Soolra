//
//  SOOLRA
//
//  Copyright © 2025 SOOLRA. All rights reserved.
//

import CoreGraphics

extension CGPoint {
    func distanceTo(_ other: CGPoint) -> CGFloat {
        sqrt((x - other.x) * (x - other.x) + (y - other.y) * (y - other.y))
    }
}
