import AppKit
import SwiftUI
import TokenRingsCore

@main
enum TokenRingsMain {
    static func main() {
        if CommandLine.arguments.contains("--dump") {
            dumpReadings()
            exit(0)
        }
        if let index = CommandLine.arguments.firstIndex(of: "--icon-preview") {
            let path = CommandLine.arguments.dropFirst(index + 1).first ?? "/tmp/token-rings-icon.png"
            writeIconPreview(to: path)
            exit(0)
        }
        TokenRingsApp.main()
    }

    private static func writeIconPreview(to path: String) {
        let image = IconRenderer.image(for: UsageScanner().scan(), pointSize: 160)
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:])
        else { exit(1) }
        do {
            try png.write(to: URL(fileURLWithPath: path))
            print(path)
        } catch {
            exit(1)
        }
    }

    private static func dumpReadings() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        var readings = UsageScanner().scan()
        if let index = readings.firstIndex(where: { $0.provider == .muse }),
           let allowance = MuseAllowanceProbe.fetch() {
            readings[index].window = allowance.window
            readings[index].weekly = allowance.weekly
            readings[index].limitsAsOf = allowance.asOf
        }

        for reading in readings {
            let tokens = reading.tokensToday.map { String($0) } ?? "-"
            var extras: [String] = []
            if let window = reading.window {
                let reset = window.resetsAt.map { formatter.string(from: $0) } ?? "-"
                extras.append("5h=\(Int(window.percent.rounded()))%used reset=\(reset)")
            }
            if let weekly = reading.weekly {
                let reset = weekly.resetsAt.map { formatter.string(from: $0) } ?? "-"
                extras.append("7d=\(Int(weekly.percent.rounded()))%used reset=\(reset)")
            }
            if let asOf = reading.limitsAsOf {
                extras.append("asOf=\(formatter.string(from: asOf))")
            }
            if let note = reading.note { extras.append(note) }
            if let error = reading.error { extras.append("error: \(error)") }
            let name = reading.provider.rawValue.padding(toLength: 9, withPad: " ", startingAt: 0)
            print("\(name) \(tokens)\t\(extras.joined(separator: " "))")
        }
    }
}

struct TokenRingsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = UsageStore()

    var body: some Scene {
        MenuBarExtra {
            PanelView()
                .environmentObject(store)
        } label: {
            Image(nsImage: store.icon)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
