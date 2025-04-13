
public protocol CheatProtocol
{
    var code: String { get }
    var type: CheatType { get }
    var name: String { get }
    var isActive: Bool { get }
}
