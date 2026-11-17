import Foundation

/// Reads the usage cache written by the installed claude-hud plugin. This is
/// the only local source for Claude subscription window limits; it avoids
/// touching OAuth credentials.
public struct ClaudeUsageCacheScanner {
    public init() {}

    public func scan(home: URL) -> (window: LimitUsage?, weekly: LimitUsage?, asOf: Date)? {
        let candidates = [
            home.appendingPathComponent(".claude/plugins/claude-hud/.usage-cache.json"),
            home.appendingPathComponent(".claude/plugins/marketplaces/claude-hud/.usage-cache.json"),
            home.appendingPathComponent(".claude/plugins/cache/claude-hud/.usage-cache.json")
        ]

        var best: (data: [String: Any], timestamp: Date)?
        for url in candidates {
            guard let contents = try? Data(contentsOf: url),
                  let object = try? JSONSerialization.jsonObject(with: contents),
                  let root = object as? [String: Any],
                  let payload = root["data"] as? [String: Any],
                  let timestamp = LogScan.double(root["timestamp"])
            else { continue }

            let observedAt = Date(timeIntervalSince1970: timestamp / 1_000)
            if let current = best, observedAt <= current.timestamp { continue }
            best = (payload, observedAt)
        }

        guard let best else { return nil }
        return (
            limit(percent: best.data["fiveHour"], reset: best.data["fiveHourResetAt"]),
            limit(percent: best.data["sevenDay"], reset: best.data["sevenDayResetAt"]),
            best.timestamp
        )
    }

    private func limit(percent: Any?, reset: Any?) -> LimitUsage? {
        guard let percent = LogScan.double(percent) else { return nil }
        let resetsAt = (reset as? String).flatMap { LogScan.date(fromISO: $0) }
        return LimitUsage(percent: percent, resetsAt: resetsAt)
    }
}
