//
//  LibraryItem.swift
//  SOOLRA
//
//  Created by Kai Yoshida on 10/08/2025.
//

import UIKit


/// What the grid renders
protocol LibraryItem {
    var id: UUID { get }
    var displayName: String { get }
    var iconImage: UIImage? { get }
    var searchKey: String { get }
}

enum LibraryKind {
    case rom(Rom)                    // stored Core Data object
    case web(WebGame)                // static/registrable config
}

extension Rom: LibraryItem {
    public var id: UUID { objectID.uriRepresentation().lastPathComponent.hashValueUUID }
    var displayName: String { name ?? "Unknown" }
    var iconImage: UIImage? { imageData.flatMap(UIImage.init(data:)) }
    var searchKey: String { displayName }
}

extension WebGame: LibraryItem {
    var displayName: String { name }
    var iconImage: UIImage? { icon }
    var searchKey: String { name }
}

private extension Int {
    var hashValueUUID: UUID { UUID(uuid: (0,0,0,0,0,0,0,0,0,0,0,0,0,0,UInt8((self>>8)&0xFF),UInt8(self&0xFF))) }
}
    
private extension String {
    var hashValueUUID: UUID {
        var hasher = Hasher()
        hasher.combine(self)
        let hashValue = hasher.finalize()
        // Convert the Int hash into a UUID by putting it in the last two bytes
        return UUID(uuid: (
            0,0,0,0,0,0,0,0,0,0,0,0,0,0,
            UInt8((hashValue >> 8) & 0xFF),
            UInt8(hashValue & 0xFF)
        ))
    }
}
