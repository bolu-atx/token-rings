import AppKit

public enum IconRenderer {
    public static func image(for readings: [ProviderReading], pointSize: CGFloat = 20) -> NSImage {
        let total = readings.compactMap { $0.tokensToday }.reduce(Int64(0), +)
        let shares: [(Provider, Double)] = readings.map { reading in
            guard total > 0, let tokens = reading.tokensToday else {
                return (reading.provider, 0)
            }
            return (reading.provider, Double(tokens) / Double(total))
        }
        return image(shares: shares, pointSize: pointSize)
    }

    public static func image(shares: [(Provider, Double)], pointSize: CGFloat = 20) -> NSImage {
        let scale: CGFloat = 2
        let pixels = max(1, Int(pointSize * scale))
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        rep.size = NSSize(width: pointSize, height: pointSize)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

        let center = NSPoint(x: pointSize / 2, y: pointSize / 2)
        let lineWidth = pointSize * 0.24
        let radius = (pointSize - lineWidth) / 2 - 0.5

        let track = NSBezierPath()
        track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        track.lineWidth = lineWidth
        NSColor(white: 0.5, alpha: 0.35).setStroke()
        track.stroke()

        let colored = shares.filter { $0.1 > 0 }
        let gap: CGFloat = colored.count > 1 ? 7 : 0
        var cursor: CGFloat = 90

        for (provider, fraction) in colored {
            let sweep = CGFloat(fraction) * 360
            if sweep >= 359.9 {
                let path = NSBezierPath()
                path.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
                path.lineWidth = lineWidth
                color(for: provider).setStroke()
                path.stroke()
            } else {
                let segmentGap = min(gap, sweep * 0.25)
                let start = cursor - segmentGap / 2
                let end = cursor - sweep + segmentGap / 2
                if end < start {
                    let path = NSBezierPath()
                    path.appendArc(
                        withCenter: center,
                        radius: radius,
                        startAngle: start,
                        endAngle: end,
                        clockwise: true
                    )
                    path.lineWidth = lineWidth
                    path.lineCapStyle = .butt
                    color(for: provider).setStroke()
                    path.stroke()
                }
            }
            cursor -= sweep
        }

        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: NSSize(width: pointSize, height: pointSize))
        image.addRepresentation(rep)
        image.isTemplate = false
        return image
    }

    private static func color(for provider: Provider) -> NSColor {
        let components = provider.colorComponents
        return NSColor(
            srgbRed: CGFloat(components.red),
            green: CGFloat(components.green),
            blue: CGFloat(components.blue),
            alpha: 1
        )
    }
}
