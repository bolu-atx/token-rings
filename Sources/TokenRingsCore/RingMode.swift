import Foundation

public enum RingMode: String, CaseIterable, Sendable {
    case tokens
    case limits

    public var title: String {
        switch self {
        case .tokens: return "Tokens"
        case .limits: return "% Used"
        }
    }
}
