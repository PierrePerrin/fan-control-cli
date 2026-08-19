import Foundation
import FanControlKit

public struct CurveCommand {
    public static func run(args: [String]) {
        var fanId: Int? = nil
        var category: SensorCategory = .cpu
        var specificSensor: String? = nil
        var minTemp: Double = 45.0
        var maxTemp: Double = 85.0
        var minRPM: Double? = nil
        var maxRPM: Double? = nil
        var interval: Double = 2.0
        var shape: CurveShape = .linear
        var points: [CurvePoint] = []
        var isBackground = false
        var logPath: String? = nil

        var i = 0
        while i < args.count {
            let arg = args[i]
            if (arg == "--fan" || arg == "-f") && i + 1 < args.count {
                let target = args[i + 1].lowercased()
                if target != "all" {
                    fanId = Int(target)
                }
                i += 1
            } else if (arg == "--sensor" || arg == "-s") && i + 1 < args.count {
                let input = args[i + 1]
                let lower = input.lowercased()
                if lower == "gpu" { category = .gpu }
                else if lower == "cpu" { category = .cpu }
                else if lower == "battery" { category = .battery }
                else if lower == "storage" { category = .storage }
                else if lower == "ambient" { category = .ambient }
                else if lower == "system" { category = .system }
                else {
                    // Passed a specific sensor name or ID (e.g. TaLP, Tp29, PMU_tcal)
                    specificSensor = input
                }
                i += 1
            } else if arg == "--sensor-id" && i + 1 < args.count {
                specificSensor = args[i + 1]
                i += 1
            } else if arg == "--min-temp" && i + 1 < args.count {
                minTemp = Double(args[i + 1]) ?? minTemp
                i += 1
            } else if arg == "--max-temp" && i + 1 < args.count {
                maxTemp = Double(args[i + 1]) ?? maxTemp
                i += 1
            } else if arg == "--min-rpm" && i + 1 < args.count {
                minRPM = Double(args[i + 1])
                i += 1
            } else if arg == "--max-rpm" && i + 1 < args.count {
                maxRPM = Double(args[i + 1])
                i += 1
            } else if (arg == "--interval" || arg == "-i") && i + 1 < args.count {
                interval = Double(args[i + 1]) ?? interval
                i += 1
            } else if arg == "--shape" && i + 1 < args.count {
                let sStr = args[i + 1].lowercased()
                if let matched = CurveShape(rawValue: sStr) {
                    shape = matched
                } else if sStr == "s" || sStr == "scurve" {
                    shape = .sCurve
                }
                i += 1
            } else if arg == "--points" && i + 1 < args.count {
                points = Self.parsePoints(args[i + 1])
                i += 1
            } else if arg == "--background" || arg == "-b" || arg == "-d" || arg == "--daemon" {
                isBackground = true
            } else if arg == "--log" && i + 1 < args.count {
                logPath = args[i + 1]
                i += 1
            }
            i += 1
        }

        let config = FanCurveConfig(
            fanId: fanId,
            sensorCategory: category,
            sensorId: specificSensor,
            minTemp: minTemp,
            maxTemp: maxTemp,
            minRPM: minRPM,
            maxRPM: maxRPM,
            shape: shape,
            points: points
        )

        let controller = FanCurveController(config: config)

        if isBackground {
            print("\(TerminalUI.green)✓ Launching Fan Curve Controller in background daemon mode...\(TerminalUI.reset)")
            let daemonArgs = ["curve"] + args
            if let pid = DaemonManager.shared.launchInBackground(args: daemonArgs, logPath: logPath) {
                print("  • Process PID : \(pid)")
                if let log = logPath {
                    print("  • Log File   : \(log)")
                } else {
                    print("  • Output     : Silenced (Terminal prompt freed)")
                }
                print("  • Run \(TerminalUI.bold)sudo fancontrol stop\(TerminalUI.reset) to stop the daemon at any time.\n")
            } else {
                print("\(TerminalUI.red)Error: Failed to launch background daemon process.\(TerminalUI.reset)")
            }
            return
        }

        // Setup signal handler to reset fans to Auto on exit
        signal(SIGINT) { _ in
            print("\n\(TerminalUI.yellow)Stopping fan curve daemon... Restoring fans to Auto mode.\(TerminalUI.reset)")
            try? FanManager.shared.resetAllToAuto()
            try? FileManager.default.removeItem(atPath: DaemonManager.pidFilePath)
            exit(0)
        }

        signal(SIGTERM) { _ in
            try? FanManager.shared.resetAllToAuto()
            try? FileManager.default.removeItem(atPath: DaemonManager.pidFilePath)
            exit(0)
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"

        if !isBackground {
            TerminalUI.printHeader("Smart Fan Curve Controller")
            print("  • Target Fan(s) : \(fanId != nil ? "Fan \(fanId!)" : "All Fans")")
            if let specific = specificSensor {
                print("  • Target Sensor : \(specific)")
            } else {
                print("  • Sensor Type   : \(category.rawValue) (Dynamic Hotspot)")
            }

            if !points.isEmpty {
                let ptsStr = points.map { pt in
                    if let p = pt.rpmPercentage { return "\(pt.tempCelsius)°C:\(Int(p))%" }
                    if let r = pt.rpmValue { return "\(pt.tempCelsius)°C:\(Int(r))RPM" }
                    return "\(pt.tempCelsius)°C"
                }.joined(separator: " -> ")
                print("  • Custom Points : \(ptsStr)")
            } else {
                print("  • Curve Range   : \(minTemp)°C -> \(maxTemp)°C (Shape: \(shape.displayName))")
            }

            if let minR = minRPM, let maxR = maxRPM {
                print("  • RPM Range     : \(Int(minR)) -> \(Int(maxR)) RPM")
            }
            print("  • Interval      : \(interval)s")
            print("  \(TerminalUI.gray)Press Ctrl+C to stop and restore Auto mode.\(TerminalUI.reset)\n")
        }

        while true {
            do {
                let result = try controller.evaluateAndApply()
                let timeStr = dateFormatter.string(from: Date())
                let speeds = result.appliedRPM.sorted(by: { $0.key < $1.key }).map { "Fan \($0.key): \(Int($0.value)) RPM" }.joined(separator: ", ")
                let tempStr = TerminalUI.formatTemperature(result.temp)
                let sensorInfo = "\(TerminalUI.bold)\(result.sensor.name)\(TerminalUI.reset) (\(result.sensor.category.rawValue))"
                let line = "[\(timeStr)] \(sensorInfo): \(tempStr) | Target Speeds: \(speeds)"
                print("\r\u{001B}[2K\(line)", terminator: "")
                fflush(stdout)
            } catch let error as SMCError {
                switch error {
                case .permissionDenied:
                    print("\n\n\(TerminalUI.red)\(TerminalUI.bold)Permission Denied:\(TerminalUI.reset)")
                    print("Running dynamic fan curve controller requires root privileges.")
                    print("Please run with \(TerminalUI.cyan)sudo\(TerminalUI.reset):")
                    print("  \(TerminalUI.bold)sudo fancontrol curve \(args.joined(separator: " "))\(TerminalUI.reset)\n")
                    exit(1)
                default:
                    print("\r\u{001B}[2K\(TerminalUI.red)Error: \(error.localizedDescription)\(TerminalUI.reset)", terminator: "")
                    fflush(stdout)
                }
            } catch {
                print("\r\u{001B}[2K\(TerminalUI.red)Error: \(error.localizedDescription)\(TerminalUI.reset)", terminator: "")
                fflush(stdout)
            }

            usleep(useconds_t(interval * 1_000_000))
        }

    }

    public static func parsePoints(_ str: String) -> [CurvePoint] {
        var points: [CurvePoint] = []
        let items = str.split(separator: ",")
        for item in items {
            let parts = item.trimmingCharacters(in: .whitespaces).split(separator: ":")
            if parts.count == 2, let temp = Double(parts[0]) {
                let valStr = String(parts[1]).trimmingCharacters(in: .whitespaces)
                if valStr.hasSuffix("%"), let pct = Double(valStr.dropLast()) {
                    points.append(CurvePoint(tempCelsius: temp, rpmPercentage: pct))
                } else if let rpm = Double(valStr) {
                    points.append(CurvePoint(tempCelsius: temp, rpmValue: rpm))
                }
            }
        }
        return points.sorted()
    }
}
