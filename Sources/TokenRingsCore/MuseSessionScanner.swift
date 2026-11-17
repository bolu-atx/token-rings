import Foundation

public struct MuseSessionScanner {
    public init() {}

    public func scan(sessionsDir: URL, day: DateInterval) -> ProviderReading {
        let exists = FileManager.default.fileExists(atPath: sessionsDir.path)
        var seen = Set<String>()
        var tokens: Int64 = 0
        var scanError: String?

        for file in LogScan.files(in: sessionsDir, updatedSince: day.start, named: "session.jsonl") {
            do {
                try LogScan.forEachJSONLine(at: file) { object in
                    guard let payload = object["payload"] as? [String: Any],
                          let event = payload["event"] as? [String: Any],
                          (event["kind"] as? String) == "goal_usage_attribution",
                          let record = event["record"] as? [String: Any],
                          (record["usage_family"] as? String) == "provider",
                          let quantity = record["quantity"] as? [String: Any],
                          (quantity["reported"] as? Bool) == true,
                          let stamp = LogScan.date(fromMicroseconds: object["recorded_at"]),
                          day.contains(stamp)
                    else { return }

                    let id = (record["usage_id"] as? String) ?? UUID().uuidString
                    guard seen.insert(id).inserted else { return }
                    tokens += LogScan.int64(quantity["input_tokens"])
                        + LogScan.int64(quantity["output_tokens"])
                }
            } catch {
                scanError = scanError ?? error.localizedDescription
            }
        }

        return ProviderReading(
            provider: .muse,
            tokensToday: exists ? tokens : nil,
            note: exists ? nil : "No Muse logs",
            error: scanError
        )
    }
}
