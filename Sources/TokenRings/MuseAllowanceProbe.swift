import Foundation
import TokenRingsCore

enum MuseAllowanceProbe {
    struct Result {
        var window: LimitUsage?
        var weekly: LimitUsage?
        var asOf: Date
    }

    static func fetch(timeout: TimeInterval = 4) -> Result? {
        guard let executable = executableURL() else { return nil }

        let process = Process()
        process.executableURL = executable
        process.arguments = ["usage", "--json"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning {
            process.terminate()
            return nil
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8),
              let brace = text.firstIndex(of: "{"),
              let json = String(text[brace...]).data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: json),
              let root = object as? [String: Any],
              let allowance = root["allowance"] as? [String: Any]
        else { return nil }

        return Result(
            window: limit(allowance["window"]),
            weekly: limit(allowance["weekly"]),
            asOf: Date()
        )
    }

    private static func limit(_ value: Any?) -> LimitUsage? {
        guard let object = value as? [String: Any],
              let percent = (object["usedPercent"] as? NSNumber)?.doubleValue else { return nil }
        let resetsAt = (object["resetsAtMs"] as? NSNumber).map {
            Date(timeIntervalSince1970: $0.doubleValue / 1_000)
        }
        return LimitUsage(percent: percent, resetsAt: resetsAt)
    }

    private static func executableURL() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent(".local/bin/muse"),
            URL(fileURLWithPath: "/opt/homebrew/bin/muse"),
            URL(fileURLWithPath: "/usr/local/bin/muse")
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
}
