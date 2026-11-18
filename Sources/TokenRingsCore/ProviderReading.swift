import Foundation

public struct LimitUsage: Sendable, Equatable {
    public var percent: Double
    public var resetsAt: Date?

    public init(percent: Double, resetsAt: Date? = nil) {
        self.percent = percent
        self.resetsAt = resetsAt
    }
}

public enum BottleneckKind: Sendable, Equatable {
    case window
    case weekly

    public var label: String {
        switch self {
        case .window: return "5h"
        case .weekly: return "Week"
        }
    }
}

public extension LimitUsage {
    /// Percent still counting against the limit. A window that already reset
    /// counts as 0% used.
    func effectivePercent(now: Date = Date()) -> Double {
        if let resetsAt, resetsAt <= now { return 0 }
        return percent
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

    /// The tighter of the 5-hour and weekly limits: whichever percent used is
    /// higher wins, since it is the first bottleneck. A window that already
    /// reset counts as 0%. Ties prefer the 5-hour window.
    public func bottleneck(now: Date = Date()) -> LimitUsage? {
        switch (window, weekly) {
        case (nil, nil):
            return nil
        case (let value?, nil):
            return value
        case (nil, let value?):
            return value
        case (let window?, let weekly?):
            return weekly.effectivePercent(now: now) > window.effectivePercent(now: now)
                ? weekly : window
        }
    }

    public func bottleneckKind(now: Date = Date()) -> BottleneckKind? {
        switch (window, weekly) {
        case (nil, nil):
            return nil
        case (.some, nil):
            return .window
        case (nil, .some):
            return .weekly
        case (let window?, let weekly?):
            return weekly.effectivePercent(now: now) > window.effectivePercent(now: now)
                ? .weekly : .window
        }
    }

    public func bottleneckPercent(now: Date = Date()) -> Double? {
        bottleneck(now: now)?.effectivePercent(now: now)
    }
}
