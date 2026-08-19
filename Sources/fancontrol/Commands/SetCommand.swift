import Foundation
import FanControlKit

public struct SetCommand {
    public static func run(args: [String]) {
        guard args.count >= 2 else {
            print("\(TerminalUI.red)Error: Missing required arguments.\(TerminalUI.reset)")
            print("Usage: fancontrol set <fan_id | left | right | all> <rpm | percentage% | auto>")
            print("Example: fancontrol set 0 3500")
            print("Example: fancontrol set all 60%")
            print("Example: fancontrol set left auto")
            exit(1)
        }

        let fanTarget = args[0].lowercased()
        let valueStr = args[1].lowercased()
        let fanManager = FanManager.shared
        let allFans = fanManager.getFans()

        guard !allFans.isEmpty else {
            print("\(TerminalUI.red)Error: No fans detected on this system.\(TerminalUI.reset)")
            exit(1)
        }

        // Determine targeted fan IDs
        var targetFanIds: [Int] = []
        if fanTarget == "all" {
            targetFanIds = allFans.map(\.id)
        } else if fanTarget == "left" || fanTarget == "0" {
            targetFanIds = [0]
        } else if fanTarget == "right" || fanTarget == "1" {
            if allFans.count > 1 {
                targetFanIds = [1]
            } else {
                print("\(TerminalUI.red)Error: Fan 'right' (1) does not exist (system only has 1 fan).\(TerminalUI.reset)")
                exit(1)
            }
        } else if let id = Int(fanTarget) {
            if allFans.contains(where: { $0.id == id }) {
                targetFanIds = [id]
            } else {
                print("\(TerminalUI.red)Error: Fan ID '\(id)' is invalid. Available fan IDs: \(allFans.map { String($0.id) }.joined(separator: ", "))\(TerminalUI.reset)")
                exit(1)
            }
        } else {
            print("\(TerminalUI.red)Error: Unknown fan target '\(fanTarget)'. Use 0, 1, left, right, or all.\(TerminalUI.reset)")
            exit(1)
        }

        do {
            if valueStr == "auto" {
                for id in targetFanIds {
                    try fanManager.setFanMode(fanId: id, mode: .auto)
                    let name = allFans.first(where: { $0.id == id })?.name ?? "Fan \(id)"
                    print("\(TerminalUI.green)✓ Restored \(name) (ID: \(id)) to Automatic system control.\(TerminalUI.reset)")
                }
            } else if valueStr.hasSuffix("%") {
                let percentStr = valueStr.trimmingCharacters(in: CharacterSet(charactersIn: "%"))
                guard let percentage = Double(percentStr) else {
                    print("\(TerminalUI.red)Error: Invalid percentage value '\(valueStr)'.\(TerminalUI.reset)")
                    exit(1)
                }
                for id in targetFanIds {
                    try fanManager.setFanPercentage(fanId: id, percentage: percentage)
                    let updated = fanManager.getFan(id: id)
                    let targetRPM = updated?.targetRPM ?? 0
                    let name = updated?.name ?? "Fan \(id)"
                    print("\(TerminalUI.green)✓ Set \(name) (ID: \(id)) to \(Int(percentage))% (Target: \(Int(targetRPM)) RPM, Mode: Manual).\(TerminalUI.reset)")
                }
            } else if let rpm = Double(valueStr) {
                for id in targetFanIds {
                    try fanManager.setFanSpeed(fanId: id, targetRPM: rpm)
                    let name = allFans.first(where: { $0.id == id })?.name ?? "Fan \(id)"
                    print("\(TerminalUI.green)✓ Set \(name) (ID: \(id)) target to \(Int(rpm)) RPM (Mode: Manual).\(TerminalUI.reset)")
                }
            } else {
                print("\(TerminalUI.red)Error: Invalid speed value '\(valueStr)'. Provide an RPM number (e.g. 3500), percentage (e.g. 50%), or 'auto'.\(TerminalUI.reset)")
                exit(1)
            }
        } catch let error as SMCError {
            switch error {
            case .permissionDenied:
                print("\n\(TerminalUI.red)\(TerminalUI.bold)Permission Denied:\(TerminalUI.reset)")
                print("Modifying fan speeds requires root privileges on macOS.")
                print("Please run with \(TerminalUI.cyan)sudo\(TerminalUI.reset):")
                print("  \(TerminalUI.bold)sudo fancontrol set \(args.joined(separator: " "))\(TerminalUI.reset)\n")
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
