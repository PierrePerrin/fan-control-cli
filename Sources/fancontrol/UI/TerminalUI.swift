import Foundation

public struct TerminalUI {
    public static let reset = "\u{001B}[0m"
    public static let bold = "\u{001B}[1m"
    public static let dim = "\u{001B}[2m"
    public static let italic = "\u{001B}[3m"
    public static let underline = "\u{001B}[4m"

    public static let black = "\u{001B}[30m"
    public static let red = "\u{001B}[31m"
    public static let green = "\u{001B}[32m"
    public static let yellow = "\u{001B}[33m"
    public static let blue = "\u{001B}[34m"
    public static let magenta = "\u{001B}[35m"
    public static let cyan = "\u{001B}[36m"
    public static let white = "\u{001B}[37m"
    public static let gray = "\u{001B}[90m"

    public static let clearScreen = "\u{001B}[2J\u{001B}[H"
    public static let hideCursor = "\u{001B}[?25l"
    public static let showCursor = "\u{001B}[?25h"

    public static func colorize(_ text: String, color: String, bold: Bool = false) -> String {
        return "\(bold ? self.bold : "")\(color)\(text)\(reset)"
    }

    public static func makeProgressBar(percentage: Double, width: Int = 20) -> String {
        let clamped = max(0.0, min(100.0, percentage))
        let filledCount = Int((clamped / 100.0) * Double(width))
        let emptyCount = max(0, width - filledCount)

        let color: String
        if clamped < 50.0 {
            color = green
        } else if clamped < 80.0 {
            color = yellow
        } else {
            color = red
        }

        let filledStr = String(repeating: "█", count: filledCount)
        let emptyStr = String(repeating: "░", count: emptyCount)

        return "\(color)\(filledStr)\(gray)\(emptyStr)\(reset)"
    }

    public static func formatTemperature(_ celsius: Double, unit: String = "C") -> String {
        let val: Double
        let unitStr: String
        if unit.uppercased() == "F" {
            val = (celsius * 9.0 / 5.0) + 32.0
            unitStr = "°F"
        } else {
            val = celsius
            unitStr = "°C"
        }

        let color: String
        if celsius < 55.0 {
            color = green
        } else if celsius < 75.0 {
            color = yellow
        } else if celsius < 90.0 {
            color = magenta
        } else {
            color = red
        }

        return String(format: "%@%5.1f%@%@", color, val, unitStr, reset)
    }

    public static func printHeader(_ title: String) {
        print("\(bold)\(cyan)=== \(title) ===\(reset)")
    }

    public static func printSection(_ title: String) {
        print("\n\(bold)\(white)▶ \(title)\(reset)")
    }
}
