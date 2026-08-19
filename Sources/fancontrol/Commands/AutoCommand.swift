import Foundation
import FanControlKit

public struct AutoCommand {
    public static func run(args: [String]) {
        let fanTarget = args.first?.lowercased() ?? "all"
        let fanManager = FanManager.shared
        let allFans = fanManager.getFans()

        guard !allFans.isEmpty else {
            print("\(TerminalUI.red)Error: No fans detected on this system.\(TerminalUI.reset)")
            exit(1)
        }

        var targetFanIds: [Int] = []
        if fanTarget == "all" {
            targetFanIds = allFans.map(\.id)
        } else if fanTarget == "left" || fanTarget == "0" {
            targetFanIds = [0]
        } else if fanTarget == "right" || fanTarget == "1" {
            targetFanIds = [1]
        } else if let id = Int(fanTarget) {
            targetFanIds = [id]
        } else {
            print("\(TerminalUI.red)Error: Unknown fan target '\(fanTarget)'. Use 0, 1, left, right, or all.\(TerminalUI.reset)")
            exit(1)
        }

        do {
            for id in targetFanIds {
                try fanManager.setFanMode(fanId: id, mode: .auto)
                let name = allFans.first(where: { $0.id == id })?.name ?? "Fan \(id)"
                print("\(TerminalUI.green)✓ Restored \(name) (ID: \(id)) to Automatic system control.\(TerminalUI.reset)")
            }
        } catch let error as SMCError {
            switch error {
            case .permissionDenied:
                print("\n\(TerminalUI.red)\(TerminalUI.bold)Permission Denied:\(TerminalUI.reset)")
                print("Resetting fan modes requires root privileges on macOS.")
                print("Please run with \(TerminalUI.cyan)sudo\(TerminalUI.reset):")
                print("  \(TerminalUI.bold)sudo fancontrol auto \(args.joined(separator: " "))\(TerminalUI.reset)\n")
                exit(1)
            default:
                print("\(TerminalUI.red)Error: \(error.localizedDescription)\(TerminalUI.reset)")
                exit(1)
            }
        } catch {
            print("\(TerminalUI.red)Error: \(error.localizedDescription)\(TerminalUI.reset)")
            exit(1)
        }
    }
}
