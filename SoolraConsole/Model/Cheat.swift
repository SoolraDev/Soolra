import Foundation

public enum CheatType: String, Codable, Hashable {
    case actionReplay = "ActionReplay"
    case gameShark = "GameShark"
    case codeBreaker = "CodeBreaker"
    case gameGenie6 = "GameGenie6"
    case gameGenie8 = "GameGenie8"
}


public struct Cheat: CheatProtocol, Codable, Hashable {
    public var code: String
    public var type: CheatType
    public var name: String
    public var isActive: Bool

    public init(code: String, type: CheatType, name: String, isActive: Bool = false) {
        self.code = code
        self.type = type
        self.name = name
        self.isActive = isActive
    }
}
