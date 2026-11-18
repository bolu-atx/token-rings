import AppKit
import Foundation
import Testing
@testable import TokenRingsCore

@Suite struct RingModeTests {
    @Test func bottleneckPicksHigherPercent() {
        let now = Date()
        let reading = ProviderReading(
            provider: .claude,
            window: LimitUsage(percent: 30, resetsAt: now.addingTimeInterval(3600)),
            weekly: LimitUsage(percent: 72, resetsAt: now.addingTimeInterval(86_400))
        )
        #expect(reading.bottleneckKind(now: now) == .weekly)
        #expect(reading.bottleneckPercent(now: now) == 72)
    }

    @Test func bottleneckPrefersWindowOnTie() {
        let now = Date()
        let reading = ProviderReading(
            provider: .codex,
            window: LimitUsage(percent: 50, resetsAt: now.addingTimeInterval(3600)),
            weekly: LimitUsage(percent: 50, resetsAt: now.addingTimeInterval(86_400))
        )
        #expect(reading.bottleneckKind(now: now) == .window)
        #expect(reading.bottleneckPercent(now: now) == 50)
    }

    @Test func bottleneckTreatsResetWindowAsZero() {
        let now = Date()
        let reading = ProviderReading(
            provider: .claude,
            window: LimitUsage(percent: 90, resetsAt: now.addingTimeInterval(-60)),
            weekly: LimitUsage(percent: 20, resetsAt: now.addingTimeInterval(86_400))
        )
        #expect(reading.bottleneckKind(now: now) == .weekly)
        #expect(reading.bottleneckPercent(now: now) == 20)
    }

    @Test func bottleneckHandlesSingleLimit() {
        let now = Date()
        let windowOnly = ProviderReading(
            provider: .codex,
            window: LimitUsage(percent: 45, resetsAt: now.addingTimeInterval(3600))
        )
        #expect(windowOnly.bottleneckKind(now: now) == .window)

        let weeklyOnly = ProviderReading(
            provider: .muse,
            weekly: LimitUsage(percent: 10, resetsAt: now.addingTimeInterval(86_400))
        )
        #expect(weeklyOnly.bottleneckKind(now: now) == .weekly)
    }

    @Test func iconRendererDrawsBothModes() {
        let readings = [
            ProviderReading(provider: .claude, tokensToday: 30),
            ProviderReading(provider: .codex, tokensToday: 70)
        ]
        #expect(IconRenderer.image(for: readings, pointSize: 20).size == NSSize(width: 20, height: 20))
        #expect(IconRenderer.image(percentUsed: 72, provider: .claude).size == NSSize(width: 20, height: 20))
        #expect(IconRenderer.image(percentUsed: 0, provider: .deepseek).size == NSSize(width: 20, height: 20))
        #expect(IconRenderer.image(percentUsed: 100, provider: .codex).size == NSSize(width: 20, height: 20))
    }

    @Test func bottleneckIsNilWithoutLimits() {
        let reading = ProviderReading(provider: .deepseek, tokensToday: 100)
        #expect(reading.bottleneck(now: Date()) == nil)
        #expect(reading.bottleneckKind(now: Date()) == nil)
        #expect(reading.bottleneckPercent(now: Date()) == nil)
    }
}
