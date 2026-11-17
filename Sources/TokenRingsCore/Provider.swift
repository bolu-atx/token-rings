import Foundation

public enum Provider: String, CaseIterable, Identifiable, Sendable {
    case claude
    case deepseek
    case codex
    case muse

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .claude: return "Claude"
        case .deepseek: return "DeepSeek"
        case .codex: return "Codex"
        case .muse: return "Muse"
        }
    }

    /// RGB components in the 0...1 range.
    public var colorComponents: (red: Double, green: Double, blue: Double) {
        switch self {
        case .claude: return (0.89, 0.34, 0.18)
        case .deepseek: return (0.18, 0.50, 0.98)
        case .codex: return (0.00, 0.66, 0.47)
        case .muse: return (0.56, 0.36, 0.85)
        }
    }

    /// Classifies a model identifier from an agent session log.
    public static func from(model: String) -> Provider? {
        let lower = model.lowercased()
        if lower.contains("deepseek") { return .deepseek }
        if lower.contains("claude") || lower == "opus" || lower == "sonnet" || lower == "haiku" {
            return .claude
        }
        return nil
    }

    public var dashboardURL: URL {
        switch self {
        case .claude:
            return URL(string: "https://claude.ai/settings/usage")!
        case .deepseek:
            return URL(string: "https://platform.deepseek.com/usage")!
        case .codex:
            return URL(string: "https://chatgpt.com/settings/usage")!
        case .muse:
            return URL(string: "https://accountscenter.meta.com/muse_code/?ep=no_payg")!
        }
    }
}
