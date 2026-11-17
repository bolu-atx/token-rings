import Foundation

public struct LimitUsage: Sendable, Equatable {
    public var percent: Double
    public var resetsAt: Date?

    public init(percent: Double, resetsAt: Date? = nil) {
        self.percent = percent
        self.resetsAt = resetsAt
    }
}

public struct ProviderReading: Identifiable, Sendable {
    public var provider: Provider
    public var tokensToday: Int64?
    public var window: LimitUsage?
    public var weekly: LimitUsage?
    public var limitsAsOf: Date?
    public var note: String?
    public var error: String?

    public var id: Provider { provider }

    public init(
        provider: Provider,
        tokensToday: Int64? = nil,
        window: LimitUsage? = nil,
        weekly: LimitUsage? = nil,
        limitsAsOf: Date? = nil,
        note: String? = nil,
        error: String? = nil
    ) {
        self.provider = provider
        self.tokensToday = tokensToday
        self.window = window
        self.weekly = weekly
        self.limitsAsOf = limitsAsOf
        self.note = note
        self.error = error
    }
}
