import SwiftUI

enum CodexTheme {
    static let sidebar = Color(hex: 0x263A3E)
    static let sidebarMuted = Color(hex: 0x8EA0A2)
    static let background = Color(hex: 0x292927)
    static let surface = Color(hex: 0x343431)
    static let surfaceRaised = Color(hex: 0x3B3B38)
    static let border = Color.white.opacity(0.07)
    static let accent = Color(hex: 0xFF8A3D)
    static let good = Color(hex: 0x37C978)
    static let warning = Color(hex: 0xE8B94F)
    static let danger = Color(hex: 0xFF6B62)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xff) / 255
        let green = Double((hex >> 8) & 0xff) / 255
        let blue = Double(hex & 0xff) / 255
        self.init(red: red, green: green, blue: blue, opacity: opacity)
    }
}

extension Notification.Name {
    static let openProjectRequested = Notification.Name("LocalCodex.openProjectRequested")
}
