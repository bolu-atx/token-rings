import Foundation

public struct ClaudeTranscriptScanner {
    public init() {}

    /// Reads Claude Code JSONL transcripts. Claude and DeepSeek turns share the
    /// same store, so both are classified from the message model.
    public func scan(projectsDir: URL, day: DateInterval) -> (claude: ProviderReading, deepseek: ProviderReading) {
        let exists = FileManager.default.fileExists(atPath: projectsDir.path)
        var messages: [String: (provider: Provider, tokens: Int64)] = [:]
        var scanError: String?

        for file in LogScan.files(in: projectsDir, updatedSince: day.start) {
            do {
                try LogScan.forEachJSONLine(at: file) { object in
                    guard (object["type"] as? String) == "assistant",
                          let message = object["message"] as? [String: Any],
                          let usage = message["usage"] as? [String: Any],
                          let model = message["model"] as? String,
                          let provider = Provider.from(model: model),
                          let stamp = LogScan.date(fromISO: object["timestamp"] as? String),
                          day.contains(stamp)
                    else { return }

                    let tokens = LogScan.int64(usage["input_tokens"])
                        + LogScan.int64(usage["output_tokens"])
                        + LogScan.int64(usage["cache_creation_input_tokens"])
                        + LogScan.int64(usage["cache_read_input_tokens"])
                    guard tokens > 0 else { return }

                    // Claude Code writes one line per content block. A message id
                    // can repeat, so keep the largest usage seen for each id.
                    let id = (message["id"] as? String) ?? (object["uuid"] as? String)
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
            note: exists ? nil : "No Claude Code logs",
            error: error
        )
    }
}
