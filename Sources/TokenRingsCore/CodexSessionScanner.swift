import Foundation

public struct CodexSessionScanner {
    public init() {}

    private struct TokenEvent {
        let stamp: Date
        let tokens: Int64
        let window: LimitUsage?
        let weekly: LimitUsage?
    }

    public func scan(sessionsDir: URL, day: DateInterval) -> ProviderReading {
        let exists = FileManager.default.fileExists(atPath: sessionsDir.path)
        let todayFiles = LogScan.files(in: sessionsDir, updatedSince: day.start)
        var tokens: Int64 = 0
        var scanError: String?
        var latestLimits: (stamp: Date, window: LimitUsage?, weekly: LimitUsage?)?

        func applyLimits(_ event: TokenEvent) {
            guard event.window != nil || event.weekly != nil else { return }
            if let current = latestLimits, event.stamp < current.stamp { return }
            latestLimits = (event.stamp, event.window, event.weekly)
        }

        for file in todayFiles {
            do {
                try LogScan.forEachJSONLine(at: file) { object in
                    guard let event = tokenEvent(from: object) else { return }
                    if day.contains(event.stamp) {
                        tokens += event.tokens
                    }
                    applyLimits(event)
                }
            } catch {
                scanError = scanError ?? error.localizedDescription
            }
        }

        // Limits survive across days. Read the newest session for the last
        // known values even when Codex has not run today.
        if let newest = LogScan.newestFile(in: sessionsDir, extension: "jsonl"),
           !todayFiles.contains(newest) {
            do {
                try LogScan.forEachJSONLine(at: newest) { object in
                    guard let event = tokenEvent(from: object) else { return }
                    applyLimits(event)
                }
            } catch {
                scanError = scanError ?? error.localizedDescription
            }
        }

        return ProviderReading(
            provider: .codex,
            tokensToday: exists ? tokens : nil,
            window: latestLimits?.window,
            weekly: latestLimits?.weekly,
            limitsAsOf: latestLimits?.stamp,
            note: exists ? nil : "No Codex logs",
            error: scanError
        )
    }

    private func tokenEvent(from object: [String: Any]) -> TokenEvent? {
        guard (object["type"] as? String) == "event_msg",
              let payload = object["payload"] as? [String: Any],
              (payload["type"] as? String) == "token_count",
              let stamp = LogScan.date(fromISO: object["timestamp"] as? String)
        else { return nil }

        var tokens: Int64 = 0
        if let info = payload["info"] as? [String: Any],
           let last = info["last_token_usage"] as? [String: Any] {
            tokens = LogScan.int64(last["total_tokens"])
        }

        var window: LimitUsage?
        var weekly: LimitUsage?
        if let limits = payload["rate_limits"] as? [String: Any] {
            window = limit(from: limits["primary"])
            weekly = limit(from: limits["secondary"])
        }

        return TokenEvent(stamp: stamp, tokens: tokens, window: window, weekly: weekly)
    }

    private func limit(from value: Any?) -> LimitUsage? {
        guard let object = value as? [String: Any],
              let percent = LogScan.double(object["used_percent"]) else { return nil }
        let resetsAt = LogScan.double(object["resets_at"]).map { Date(timeIntervalSince1970: $0) }
        return LimitUsage(percent: percent, resetsAt: resetsAt)
    }
}
