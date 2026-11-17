import Foundation

public struct UsageScanner {
    public let home: URL
    public let now: Date
    public let calendar: Calendar

    public init(
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.home = home
        self.now = now
        self.calendar = calendar
    }

    public func scan() -> [ProviderReading] {
        guard let day = calendar.dateInterval(of: .day, for: now) else {
            return Provider.allCases.map {
                ProviderReading(provider: $0, error: "Cannot determine today")
            }
        }

        let transcripts = ClaudeTranscriptScanner().scan(
            projectsDir: home.appendingPathComponent(".claude/projects"),
            day: day
        )
        let pi = PiSessionScanner().scan(
            sessionsDir: home.appendingPathComponent(".pi/agent/sessions"),
            day: day
        )
        let codex = CodexSessionScanner().scan(
            sessionsDir: home.appendingPathComponent(".codex/sessions"),
            day: day
        )
        let muse = MuseSessionScanner().scan(
            sessionsDir: home.appendingPathComponent(".local/share/muse/sessions"),
            day: day
        )

        var claude = merge([transcripts.claude, pi.claude], provider: .claude)
        if let limits = ClaudeUsageCacheScanner().scan(home: home) {
            claude.window = limits.window
            claude.weekly = limits.weekly
            claude.limitsAsOf = limits.asOf
        }

        return [
            claude,
            merge([transcripts.deepseek, pi.deepseek], provider: .deepseek),
            codex,
            muse
        ]
    }

    private func merge(_ readings: [ProviderReading], provider: Provider) -> ProviderReading {
        let available = readings.contains { $0.tokensToday != nil }
        let tokens = available ? readings.compactMap { $0.tokensToday }.reduce(Int64(0), +) : nil
        let errors = readings.compactMap { $0.error }
        return ProviderReading(
            provider: provider,
            tokensToday: tokens,
            note: available ? nil : "No \(provider.title) logs",
            error: errors.isEmpty ? nil : errors.joined(separator: "; ")
        )
    }
}
