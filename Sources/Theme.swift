import AppKit
import SwiftUI

enum Metrics {
    /// 卡片四周留给阴影的边距。
    static let shadowInset: CGFloat = 8
    static let fallbackWindow = NSSize(width: 216, height: 216)
    static let maxWidget = NSSize(width: 420, height: 420)
    static let bubble: CGFloat = 64
    static let settings = NSSize(width: 500, height: 620)
    static let stats = NSSize(width: 540, height: 680)

    /// 主界面卡片边长，按当前屏幕的物理尺寸换算成约 4 厘米。
    static func cardSide(on screen: NSScreen?) -> CGFloat {
        guard let screen,
              let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return 200
        }
        let millimeters = CGDisplayScreenSize(number)
        guard millimeters.width > 1, screen.frame.width > 1 else { return 200 }
        let points = 40.0 / millimeters.width * screen.frame.width
        return min(240, max(168, points.rounded()))
    }

    static func windowSide(on screen: NSScreen?) -> CGFloat {
        cardSide(on: screen) + shadowInset * 2
    }
}

enum Palette {
    static let presets = [
        "#2E9BFF", "#34C759", "#FF9F0A", "#FF375F",
        "#BF5AF2", "#64D2FF", "#FFD60A", "#5E5CE6"
    ]
}

extension NSColor {
    convenience init?(hex: String) {
        var raw = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if raw.hasPrefix("#") {
            raw.removeFirst()
        }
        guard raw.count == 6, let value = UInt32(raw, radix: 16) else { return nil }
        let red = CGFloat((value >> 16) & 0xFF) / 255
        let green = CGFloat((value >> 8) & 0xFF) / 255
        let blue = CGFloat(value & 0xFF) / 255
        self.init(srgbRed: red, green: green, blue: blue, alpha: 1)
    }

    var hexString: String {
        guard let rgb = usingColorSpace(.sRGB) else { return "#2E9BFF" }
        return String(
            format: "#%02X%02X%02X",
            colorByte(rgb.redComponent),
            colorByte(rgb.greenComponent),
            colorByte(rgb.blueComponent)
        )
    }
}

private func colorByte(_ value: CGFloat) -> Int {
    Int((min(1, max(0, value)) * 255).rounded())
}

extension Color {
    init?(hex: String) {
        guard let color = NSColor(hex: hex) else { return nil }
        self.init(nsColor: color)
    }

    /// 浅色背景上用深色字，深色背景上用浅色字。
    var prefersDarkText: Bool {
        let rgb = NSColor(self).usingColorSpace(.sRGB)
        let red = rgb?.redComponent ?? 0
        let green = rgb?.greenComponent ?? 0
        let blue = rgb?.blueComponent ?? 0
        return (0.2126 * red + 0.7152 * green + 0.0722 * blue) > 0.62
    }
}

/// 把颜色按比例变暗，兼容 macOS 14。
func darker(_ color: Color, by factor: Double) -> Color {
    guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return color }
    let f = max(0, 1 - factor)
    return Color(
        .sRGB,
        red: Double(rgb.redComponent) * f,
        green: Double(rgb.greenComponent) * f,
        blue: Double(rgb.blueComponent) * f,
        opacity: Double(rgb.alphaComponent)
    )
}
