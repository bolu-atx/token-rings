import Foundation
import Testing
@testable import TokenRingsCore

@Suite struct ScannerTests {
    @Test func claudeTranscriptDeduplicatesAndSplitsProviders() throws {
        let tempRoot = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let projects = tempRoot.appendingPathComponent(".claude/projects/-tmp-project", isDirectory: true)
        try FileManager.default.createDirectory(at: projects, withIntermediateDirectories: true)

        let now = Date()
        let day = Calendar.current.dateInterval(of: .day, for: now)!
        let today = isoString(now)
        let yesterday = isoString(now.addingTimeInterval(-86_400))

        try writeJSONLines([
            claudeLine(id: "m1", model: "claude-opus-5-5", input: 10, output: 5, timestamp: today),
            claudeLine(id: "m1", model: "claude-opus-5-5", input: 20, output: 10, timestamp: today),
            claudeLine(id: "m2", model: "deepseek-flash[1m]", input: 100, output: 20, timestamp: today),
            claudeLine(id: "m3", model: "claude-opus-5-5", input: 999, output: 999, timestamp: yesterday)
        ], to: projects.appendingPathComponent("session.jsonl"))

        let result = ClaudeTranscriptScanner().scan(
            projectsDir: tempRoot.appendingPathComponent(".claude/projects"),
            day: day
        )

        #expect(result.claude.tokensToday == 30)
        #expect(result.deepseek.tokensToday == 120)
    }

    @Test func piSplitsModelsAndDeduplicates() throws {
        let tempRoot = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let sessions = tempRoot.appendingPathComponent(".pi/agent/sessions/-tmp-project", isDirectory: true)
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)

        let now = Date()
        let day = Calendar.current.dateInterval(of: .day, for: now)!
        let today = isoString(now)
        let yesterday = isoString(now.addingTimeInterval(-86_400))

        try writeJSONLines([
            piLine(id: "p1", model: "deepseek-v4-pro", total: 1_000, timestamp: today),
            piLine(id: "p1", model: "deepseek-v4-pro", total: 1_000, timestamp: today),
            piLine(id: "p2", model: "claude-opus-5-5", total: 500, timestamp: today),
            piLine(id: "p3", model: "deepseek-v4-pro", total: 700, timestamp: yesterday)
        ], to: sessions.appendingPathComponent("session.jsonl"))

        let result = PiSessionScanner().scan(
            sessionsDir: tempRoot.appendingPathComponent(".pi/agent/sessions"),
            day: day
        )

        #expect(result.deepseek.tokensToday == 1_000)
        #expect(result.claude.tokensToday == 500)
    }

    @Test func codexSumsTurnDeltasAndReadsLimits() throws {
        let tempRoot = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let sessions = tempRoot.appendingPathComponent(".codex/sessions/2026/11/16", isDirectory: true)
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)

        let now = Date()
        let day = Calendar.current.dateInterval(of: .day, for: now)!
        let today = isoString(now)
        let yesterday = isoString(now.addingTimeInterval(-86_400))

        try writeJSONLines([
            codexLine(timestamp: today, total: 100, percent: 40),
            codexLine(timestamp: today, total: 50, percent: 45),
            codexLine(timestamp: yesterday, total: 900, percent: 99)
        ], to: sessions.appendingPathComponent("rollout.jsonl"))

        let reading = CodexSessionScanner().scan(
            sessionsDir: tempRoot.appendingPathComponent(".codex/sessions"),
            day: day
        )

        #expect(reading.tokensToday == 150)
        #expect(reading.window?.percent == 45)
    }

    @Test func codexReadsLimitsFromLastSessionWithoutTodayUsage() throws {
        let tempRoot = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let sessions = tempRoot.appendingPathComponent(".codex/sessions/2026/11/09", isDirectory: true)
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)

        let now = Date()
        let day = Calendar.current.dateInterval(of: .day, for: now)!
        let file = sessions.appendingPathComponent("rollout.jsonl")
        try writeJSONLines([
            codexLine(timestamp: isoString(now.addingTimeInterval(-86_400)), total: 900, percent: 60)
        ], to: file)
        try FileManager.default.setAttributes(
            [.modificationDate: now.addingTimeInterval(-86_400)],
            ofItemAtPath: file.path
        )

        let reading = CodexSessionScanner().scan(
            sessionsDir: tempRoot.appendingPathComponent(".codex/sessions"),
            day: day
        )

        #expect(reading.tokensToday == 0)
        #expect(reading.window?.percent == 60)
        #expect(reading.limitsAsOf != nil)
    }

    @Test func claudeUsageCacheReadsHudLimits() throws {
        let tempRoot = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let hud = tempRoot.appendingPathComponent(".claude/plugins/claude-hud", isDirectory: true)
        try FileManager.default.createDirectory(at: hud, withIntermediateDirectories: true)

        let object: [String: Any] = [
            "data": [
                "fiveHour": 12.5,
                "sevenDay": 72.0,
                "fiveHourResetAt": "2026-11-16T16:00:00.000Z",
                "sevenDayResetAt": "2026-11-20T17:59:59.000Z"
            ],
            "timestamp": 1_700_000_000_000 as Int64
        ]
        let data = try JSONSerialization.data(withJSONObject: object)
        try data.write(to: hud.appendingPathComponent(".usage-cache.json"))

        let result = try #require(ClaudeUsageCacheScanner().scan(home: tempRoot))

        #expect(result.window?.percent == 12.5)
        #expect(result.weekly?.percent == 72)
        #expect(result.window?.resetsAt != nil)
        #expect(result.asOf == Date(timeIntervalSince1970: 1_700_000_000))
    }

    @Test func museSumsReportedProviderLedgerOnce() throws {
        let tempRoot = try makeTempRoot()
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let session = tempRoot.appendingPathComponent(
            ".local/share/muse/sessions/2026/11/16/abc",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: session, withIntermediateDirectories: true)

        let now = Date()
        let day = Calendar.current.dateInterval(of: .day, for: now)!
        let micros = Int64(now.timeIntervalSince1970 * 1_000_000)

        try writeJSONLines([
            museLine(usageID: "u1", family: "provider", reported: true, input: 100, output: 10, micros: micros),
            museLine(usageID: "u1", family: "provider", reported: true, input: 100, output: 10, micros: micros),
            museLine(usageID: "u2", family: "tool", reported: true, input: 900, output: 900, micros: micros),
            museLine(usageID: "u3", family: "provider", reported: false, input: 500, output: 500, micros: micros)
        ], to: session.appendingPathComponent("session.jsonl"))

        let reading = MuseSessionScanner().scan(
            sessionsDir: tempRoot.appendingPathComponent(".local/share/muse/sessions"),
            day: day
        )

        #expect(reading.tokensToday == 110)
    }

    @Test func providerDashboardURLsAreHTTPS() {
        #expect(Provider.claude.dashboardURL.host == "claude.ai")
        #expect(Provider.deepseek.dashboardURL.host == "platform.deepseek.com")
        #expect(Provider.codex.dashboardURL.host == "chatgpt.com")
        #expect(Provider.muse.dashboardURL.host == "accountscenter.meta.com")
        for provider in Provider.allCases {
            #expect(provider.dashboardURL.scheme == "https")
        }
    }

    private func makeTempRoot() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("token-rings-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func claudeLine(id: String, model: String, input: Int, output: Int, timestamp: String) -> [String: Any] {
        let message: [String: Any] = [
            "id": id,
            "model": model,
            "usage": [
                "input_tokens": input,
                "output_tokens": output,
                "cache_creation_input_tokens": 0,
                "cache_read_input_tokens": 0
            ]
        ]
        return ["type": "assistant", "timestamp": timestamp, "message": message]
    }

    private func piLine(id: String, model: String, total: Int, timestamp: String) -> [String: Any] {
        let message: [String: Any] = [
            "role": "assistant",
            "model": model,
            "usage": ["totalTokens": total]
        ]
        return ["type": "message", "id": id, "timestamp": timestamp, "message": message]
    }

    private func codexLine(timestamp: String, total: Int, percent: Double) -> [String: Any] {
        let payload: [String: Any] = [
            "type": "token_count",
            "info": ["last_token_usage": ["total_tokens": total]],
            "rate_limits": [
                "primary": ["used_percent": percent, "resets_at": 1_800_000_000],
                "secondary": ["used_percent": 50.0, "resets_at": 1_800_000_000]
            ]
        ]
        return ["type": "event_msg", "timestamp": timestamp, "payload": payload]
    }

    private func museLine(
        usageID: String,
        family: String,
        reported: Bool,
        input: Int,
        output: Int,
        micros: Int64
    ) -> [String: Any] {
        let record: [String: Any] = [
            "usage_id": usageID,
            "usage_family": family,
            "quantity": ["reported": reported, "input_tokens": input, "output_tokens": output]
        ]
        return [
            "recorded_at": micros,
            "payload": ["event": ["kind": "goal_usage_attribution", "record": record]]
        ]
    }

    private func writeJSONLines(_ objects: [[String: Any]], to url: URL) throws {
        var data = Data()
        for object in objects {
            data.append(try JSONSerialization.data(withJSONObject: object))
            data.append(0x0A)
        }
        try data.write(to: url)
    }

    private func isoString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
