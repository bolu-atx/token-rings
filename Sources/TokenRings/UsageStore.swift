import AppKit
import Foundation
import TokenRingsCore
import os

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var readings: [ProviderReading]
    @Published private(set) var icon: NSImage
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastRefresh: Date?

    private let log = Logger(subsystem: "dev.blu.tokenrings", category: "usage")
    private var timer: Timer?
    private var refreshTask: Task<Void, Never>?
    private var museAllowance: MuseAllowanceProbe.Result?
    private var lastMuseAttempt: Date?

    init() {
        let initial = Provider.allCases.map { ProviderReading(provider: $0) }
        readings = initial
        icon = IconRenderer.image(for: initial)
        startTimer()
        refresh(forceMuse: true)
    }

    var totalToday: Int64 {
        readings.compactMap { $0.tokensToday }.reduce(Int64(0), +)
    }

    func share(of provider: Provider) -> Double {
        guard totalToday > 0,
              let tokens = readings.first(where: { $0.provider == provider })?.tokensToday else {
            return 0
        }
        return Double(tokens) / Double(totalToday)
    }

    func refreshIfStale() {
        if let lastRefresh, Date().timeIntervalSince(lastRefresh) < 120 { return }
        refresh()
    }

    func refresh(forceMuse: Bool = false) {
        guard !isRefreshing else { return }
        isRefreshing = true

        let now = Date()
        let home = FileManager.default.homeDirectoryForCurrentUser
        let calendar = Calendar.current
        let shouldFetchMuse = forceMuse || lastMuseAttempt.map { now.timeIntervalSince($0) > 300 } ?? true

        refreshTask = Task.detached(priority: .utility) {
            let readings = UsageScanner(home: home, now: now, calendar: calendar).scan()
            let allowance = shouldFetchMuse ? MuseAllowanceProbe.fetch() : nil

            await MainActor.run { [weak self] in
                guard let self else { return }
                if let allowance {
                    self.museAllowance = allowance
                }
                if shouldFetchMuse {
                    self.lastMuseAttempt = Date()
                }
                self.apply(readings: readings, refreshedAt: now)
            }
        }
    }

    private func apply(readings: [ProviderReading], refreshedAt: Date) {
        var updated = readings
        if let museAllowance, let index = updated.firstIndex(where: { $0.provider == .muse }) {
            updated[index].window = museAllowance.window
            updated[index].weekly = museAllowance.weekly
            updated[index].limitsAsOf = museAllowance.asOf
        }
        self.readings = updated
        icon = IconRenderer.image(for: updated)
        lastRefresh = refreshedAt
        isRefreshing = false

        let total = totalToday
        log.info("Refreshed: \(total, privacy: .public) tokens today")
    }

    private func startTimer() {
        // A full scan re-reads today's session logs, which can be large. Five
        // minutes keeps the app idle while staying current enough for totals.
        let timer = Timer(timeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        timer.tolerance = 30
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    deinit {
        timer?.invalidate()
        refreshTask?.cancel()
    }
}
