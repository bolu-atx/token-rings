import Foundation

public struct PiSessionScanner {
    public init() {}

    /// Reads pi agent session logs. DeepSeek calls made through pi are not in
    /// the Claude Code store, so they are counted here.
    public func scan(sessionsDir: URL, day: DateInterval) -> (claude: ProviderReading, deepseek: ProviderReading) {
        let exists = FileManager.default.fileExists(atPath: sessionsDir.path)
        var messages: [String: (provider: Provider, tokens: Int64)] = [:]
        var scanError: String?

        for file in LogScan.files(in: sessionsDir, updatedSince: day.start) {
            do {
                try LogScan.forEachJSONLine(at: file) { object in
                    guard let message = object["message"] as? [String: Any],
                          (message["role"] as? String) == "assistant",
                          let usage = message["usage"] as? [String: Any],
                          let model = message["model"] as? String,
                          let provider = Provider.from(model: model),
                          let stamp = LogScan.date(fromISO: object["timestamp"] as? String),
                          day.contains(stamp)
                    else { return }

                    var tokens = LogScan.int64(usage["totalTokens"])
                    if tokens == 0 {
                        tokens = LogScan.int64(usage["input"])
                            + LogScan.int64(usage["output"])
                            + LogScan.int64(usage["cacheRead"])
                            + LogScan.int64(usage["cacheWrite"])
                    }
                    guard tokens > 0 else { return }

                    let id = (object["id"] as? String) ?? (message["responseId"] as? String)
                    if let id, let existing = messages[id], existing.tokens >= tokens { return }
                    messages[id ?? UUID().uuidString] = (provider, tokens)
                }
            } catch {
                scanError = scanError ?? error.localizedDescription
            }
        }

        var totals: [Provider: Int64] = [:]
        for value in messages.values {
            totals[value.provider, default: 0] += value.tokens
        }

        return (
            makeReading(provider: .claude, exists: exists, tokens: totals[.claude] ?? 0, error: scanError),
            makeReading(provider: .deepseek, exists: exists, tokens: totals[.deepseek] ?? 0, error: scanError)
        )
    }

    private func makeReading(provider: Provider, exists: Bool, tokens: Int64, error: String?) -> ProviderReading {
        ProviderReading(
            provider: provider,
            tokensToday: exists ? tokens : nil,
            note: exists ? nil : "No pi logs",
            error: error
        )
    }
}
