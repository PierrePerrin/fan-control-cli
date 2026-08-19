import Foundation
import FanControlKit

public struct StatusCommand {
    public static func run(isJSON: Bool, unit: String = "C") {
        let state = FanManager.shared.getThermalState()

        if isJSON {
            print(JSONFormatter.encode(state))
            return
        }

        TerminalUI.printHeader("macOS Fan & Thermal Status")

        // Fans Section
        TerminalUI.printSection("Fans")
        if state.fans.isEmpty {
            print("  \(TerminalUI.gray)No fans detected (passive cooling or virtualized environment).\(TerminalUI.reset)")
        } else {
            print("  \(TerminalUI.bold)\(TerminalUI.gray)ID  Name         Current     Target      Min / Max       Mode    Load\(TerminalUI.reset)")
            print("  \(TerminalUI.gray)-----------------------------------------------------------------------\(TerminalUI.reset)")
            for fan in state.fans {
                let bar = TerminalUI.makeProgressBar(percentage: fan.percentage, width: 14)
                let modeColor = (fan.mode == .manual) ? TerminalUI.yellow : TerminalUI.cyan
                let line = String(
                    format: "  %-2d  %-11@ %5.0f RPM  %5.0f RPM  %4.0f / %4.0f RPM  %@%-6@%@  [%@] %3.0f%%",
                    fan.id,
                    fan.name,
                    fan.currentRPM,
                    fan.targetRPM,
                    fan.minRPM,
                    fan.maxRPM,
                    modeColor,
                    fan.mode.rawValue,
                    TerminalUI.reset,
                    bar,
                    fan.percentage
                )
                print(line)
            }
        }

        // Thermal Summary Section
        TerminalUI.printSection("Thermal Summary")
        var summaries: [(label: String, val: Double?)] = []
        if let cpuMax = state.cpuMaxTemp {
            summaries.append(("CPU (Max)", cpuMax))
        }
        if let cpuAvg = state.cpuAverageTemp {
            summaries.append(("CPU (Avg)", cpuAvg))
        }
        if let gpuMax = state.gpuMaxTemp {
            summaries.append(("GPU (Max)", gpuMax))
        }
        if let batt = state.batteryTemp {
            summaries.append(("Battery", batt))
        }
        if let amb = state.ambientTemp {
            summaries.append(("Ambient", amb))
        }

        if summaries.isEmpty {
            print("  \(TerminalUI.gray)No thermal sensors available.\(TerminalUI.reset)")
        } else {
            for item in summaries {
                if let temp = item.val {
                    let formatted = TerminalUI.formatTemperature(temp, unit: unit)
                    print(String(format: "  • %-16@ : %@", item.label, formatted))
                }
            }
        }

        print("\n\(TerminalUI.gray)Tip: Run 'fancontrol sensors' to list all sensors, or 'fancontrol watch' for real-time dashboard.\(TerminalUI.reset)")
    }
}
