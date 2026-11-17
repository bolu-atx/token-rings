import Foundation

enum LogScan {
    static let isoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let iso: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func date(fromISO string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        return isoFractional.date(from: string) ?? iso.date(from: string)
    }

    static func date(fromMicroseconds value: Any?) -> Date? {
        guard let number = value as? NSNumber else { return nil }
        return Date(timeIntervalSince1970: number.doubleValue / 1_000_000)
    }

    static func int64(_ value: Any?) -> Int64 {
        (value as? NSNumber)?.int64Value ?? 0
    }

    static func double(_ value: Any?) -> Double? {
        (value as? NSNumber)?.doubleValue
    }

    static func files(in root: URL, updatedSince start: Date, named name: String? = nil) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var files: [URL] = []
        for case let url as URL in enumerator {
            if let name {
                if url.lastPathComponent != name { continue }
            } else if url.pathExtension != "jsonl" {
                continue
            }

            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey]),
                  values.isRegularFile == true else { continue }
            if let modified = values.contentModificationDate, modified < start { continue }
            files.append(url)
        }
        return files
    }

    static func newestFile(in root: URL, extension ext: String) -> URL? {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return nil }

        var newest: (url: URL, modified: Date)?
        for case let url as URL in enumerator where url.pathExtension == ext {
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey]),
                  values.isRegularFile == true,
                  let modified = values.contentModificationDate
            else { continue }
            if let current = newest, modified <= current.modified { continue }
            newest = (url, modified)
        }
        return newest?.url
    }

    static func forEachJSONLine(at url: URL, _ body: ([String: Any]) throws -> Void) throws {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var buffer = Data()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            buffer.append(chunk)
            while let newline = buffer.firstIndex(of: 0x0A) {
                let line = Data(buffer[buffer.startIndex..<newline])
                buffer.removeSubrange(buffer.startIndex...newline)
                try decode(line, body)
            }
        }
        if !buffer.isEmpty {
            try decode(buffer, body)
        }
    }

    private static func decode(_ bytes: Data, _ body: ([String: Any]) throws -> Void) throws {
        guard !bytes.isEmpty,
              let object = try? JSONSerialization.jsonObject(with: bytes),
              let dictionary = object as? [String: Any] else { return }
        try body(dictionary)
    }
}
