import Foundation
import FanControlKit

public struct WatchCommand {
    private static var isRunning = true

    public static func run(args: [String], unit: String = "C") {
        var interval: Double = 1.0
        var currentUnit = unit

        var i = 0
        while i < args.count {
            let arg = args[i]
            if (arg == "--interval" || arg == "-i") && i + 1 < args.count {
                if let val = Double(args[i + 1]), val > 0.1 {
                    interval = val
                }
                i += 1
            } else if (arg == "--unit" || arg == "-u") && i + 1 < args.count {
                currentUnit = args[i + 1]
                i += 1
            }
            i += 1
        }

        // Setup signal handling for clean exit
        signal(SIGINT) { _ in
            print(TerminalUI.showCursor)
            print("\n\(TerminalUI.cyan)Exiting monitor mode.\(TerminalUI.reset)")
            exit(0)
        }

        print(TerminalUI.hideCursor)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"

        let fanManager = FanManager.shared
        let sensorManager = SensorManager.shared

        while isRunning {
            let now = Date()
            let timeStr = dateFormatter.string(from: now)
            let fans = fanManager.getFans()
            let sensors = sensorManager.discoverSensors()
            let state = ThermalState(timestamp: now, fans: fans, sensors: sensors)

            var output = TerminalUI.clearScreen
            output += "\(TerminalUI.bold)\(TerminalUI.cyan)=== macOS Fan Control Live Monitor [\(timeStr)] ===\(TerminalUI.reset)\n"
            output += "\(TerminalUI.gray)Press Ctrl+C to stop.\(TerminalUI.reset)\n\n"

            // Fans
            output += "\(TerminalUI.bold)\(TerminalUI.white)▶ Fans\(TerminalUI.reset)\n"
            if fans.isEmpty {
                output += "  \(TerminalUI.gray)No fans detected.\(TerminalUI.reset)\n"
            } else {
                output += "  \(TerminalUI.bold)\(TerminalUI.gray)ID  Name         Current     Target      Min / Max       Mode    Load\(TerminalUI.reset)\n"
                output += "  \(TerminalUI.gray)-----------------------------------------------------------------------\(TerminalUI.reset)\n"
                for fan in fans {
                    let bar = TerminalUI.makeProgressBar(percentage: fan.percentage, width: 14)
                    let modeColor = (fan.mode == .manual) ? TerminalUI.yellow : TerminalUI.cyan
                    output += String(
                        format: "  %-2d  %-11@ %5.0f RPM  %5.0f RPM  %4.0f / %4.0f RPM  %@%-6@%@  [%@] %3.0f%%\n",
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
                }
            }

            // Thermals
            output += "\n\(TerminalUI.bold)\(TerminalUI.white)▶ Thermal Overview\(TerminalUI.reset)\n"
            if let cpuMax = state.cpuMaxTemp {
                output += "  • CPU (Max)        : \(TerminalUI.formatTemperature(cpuMax, unit: currentUnit))\n"
            }
            if let cpuAvg = state.cpuAverageTemp {
                output += "  • CPU (Avg)        : \(TerminalUI.formatTemperature(cpuAvg, unit: currentUnit))\n"
            }
            if let gpuMax = state.gpuMaxTemp {
                output += "  • GPU (Max)        : \(TerminalUI.formatTemperature(gpuMax, unit: currentUnit))\n"
            }
            if let batt = state.batteryTemp {
                output += "  • Battery          : \(TerminalUI.formatTemperature(batt, unit: currentUnit))\n"
            }
            if let amb = state.ambientTemp {
                output += "  • Ambient          : \(TerminalUI.formatTemperature(amb, unit: currentUnit))\n"
            }

            // Top Hottest Sensors
            let topSensors = sensors
                .filter { $0.temperatureCelsius > 10.0 && $0.temperatureCelsius < 125.0 }
                .sorted { $0.temperatureCelsius > $1.temperatureCelsius }
                .prefix(5)

            if !topSensors.isEmpty {
                output += "\n\(TerminalUI.bold)\(TerminalUI.white)▶ Top Hotspots\(TerminalUI.reset)\n"
                for s in topSensors {
                    let formatted = TerminalUI.formatTemperature(s.temperatureCelsius, unit: currentUnit)
                    let namePad = s.name.padding(toLength: 32, withPad: " ", startingAt: 0)
                    output += "  • \(namePad) [\(s.category.rawValue)]: \(formatted)\n"
                }
            }

            print(output, terminator: "")
            fflush(stdout)

            usleep(useconds_t(interval * 1_000_000))
        }

        print(TerminalUI.showCursor)
    }
}
