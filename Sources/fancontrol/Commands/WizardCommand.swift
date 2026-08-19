import Foundation
import FanControlKit

public struct WizardCommand {
    struct Preset {
        let name: String
        let description: String
        let minTemp: Double
        let maxTemp: Double
    }

    public static func run(args: [String]) {
        TerminalUI.printHeader("Custom Fan Curve Setup Wizard")
        print("This wizard will help you configure a smart temperature-driven fan curve tailored to your hardware.\n")

        // 1. Detect Fans
        let fanManager = FanManager.shared
        let sensorManager = SensorManager.shared
        let fans = fanManager.getFans()

        if fans.isEmpty {
            print("\(TerminalUI.red)Error: No fans detected on this system.\(TerminalUI.reset)")
            return
        }

        // Target Fan Selection
        TerminalUI.printSection("Step 1: Select Target Fan(s)")
        print("  [0] All Fans (\(fans.count) fans detected)")
        for fan in fans {
            print("  [\(fan.id + 1)] Fan \(fan.id): \(fan.name) (Speed range: \(Int(fan.minRPM)) - \(Int(fan.maxRPM)) RPM)")
        }
        let fanChoice = promptInt(prompt: "Select Fan option", minVal: 0, maxVal: fans.count, defaultVal: 0)
        let selectedFanId: Int? = fanChoice == 0 ? nil : (fanChoice - 1)

        // Calculate global or selected fan RPM limits
        let targetFans = selectedFanId != nil ? fans.filter { $0.id == selectedFanId! } : fans
        let defaultMinRPM = targetFans.map { $0.minRPM }.max() ?? 2000.0
        let defaultMaxRPM = targetFans.map { $0.maxRPM }.min() ?? 6000.0

        // 2. Target Thermal Sensor Selection
        TerminalUI.printSection("Step 2: Select Thermal Sensor Source")
        let categories: [(SensorCategory, String, String)] = [
            (.ambient, "Ambient / Keyboard / Palmrest", "Monitors external chassis / keyboard surface warmth (Typical range: 25°C - 45°C)"),
            (.cpu, "CPU (Processor Hotspot)", "Monitors core processor thermal hotspot (Typical range: 40°C - 100°C)"),
            (.gpu, "GPU (Graphics Engine)", "Monitors graphics core temperature (Typical range: 40°C - 95°C)"),
            (.battery, "Battery System", "Monitors battery pack temperature (Typical range: 25°C - 45°C)"),
            (.storage, "Storage (SSD / Disk)", "Monitors NVMe / SSD drive temperature (Typical range: 30°C - 60°C)"),
            (.system, "System / Power Supply", "Monitors power delivery & ambient internal air")
        ]

        let availableSensors = sensorManager.discoverSensors()

        for (idx, cat) in categories.enumerated() {
            let catSensors = availableSensors.filter { $0.category == cat.0 }
            let maxTempStr: String
            if let hottest = catSensors.max(by: { $0.temperatureCelsius < $1.temperatureCelsius }) {
                maxTempStr = "\(TerminalUI.green)\(String(format: "%.1f", hottest.temperatureCelsius))°C\(TerminalUI.reset) (via \(hottest.name))"
            } else {
                maxTempStr = "N/A"
            }
            print("  [\(idx + 1)] \(cat.1)\n      \(TerminalUI.gray)\(cat.2)\(TerminalUI.reset)\n      Current Reading: \(maxTempStr)")
        }

        print("  [\(categories.count + 1)] Pick a Specific Named Sensor")

        let catChoice = promptInt(prompt: "Select Sensor option", minVal: 1, maxVal: categories.count + 1, defaultVal: 1)

        let chosenCategory: SensorCategory
        var chosenSensorId: String? = nil
        var sensorDisplayName = ""

        if catChoice <= categories.count {
            chosenCategory = categories[catChoice - 1].0
            sensorDisplayName = categories[catChoice - 1].1
        } else {
            // Pick specific sensor
            TerminalUI.printSection("Select Specific Thermal Sensor")
            for (idx, sensor) in availableSensors.enumerated() {
                let tempStr = TerminalUI.formatTemperature(sensor.temperatureCelsius)
                print(String(format: "  [%2d] %-30s | %-10s | Current: %@", idx + 1, sensor.name, "[\(sensor.category.rawValue)]", tempStr))
            }
            let sensIdx = promptInt(prompt: "Select Sensor", minVal: 1, maxVal: availableSensors.count, defaultVal: 1) - 1
            let selectedSensor = availableSensors[sensIdx]
            chosenCategory = selectedSensor.category
            chosenSensorId = selectedSensor.id
            sensorDisplayName = selectedSensor.name
        }

        // Get live reading for chosen target
        let activeTemp: Double
        if let specId = chosenSensorId {
            activeTemp = availableSensors.first(where: { $0.id == specId })?.temperatureCelsius ?? 35.0
        } else {
            let catSensors = availableSensors.filter { $0.category == chosenCategory }
            activeTemp = catSensors.max(by: { $0.temperatureCelsius < $1.temperatureCelsius })?.temperatureCelsius ?? 35.0
        }

        print("\nSelected Sensor Target: \(TerminalUI.bold)\(sensorDisplayName)\(TerminalUI.reset) (Current Temp: \(TerminalUI.formatTemperature(activeTemp)))")

        // 3. Sensor-Adapted Presets & Thresholds
        TerminalUI.printSection("Step 3: Select Curve Profile & Thresholds")

        let presets: [Preset]
        switch chosenCategory {
        case .ambient:
            presets = [
                Preset(name: "Silent Keyboard (Warm Surface Allowed)", description: "Keeps fans whisper-quiet unless keyboard surface reaches warm temperatures.", minTemp: 36.0, maxTemp: 44.0),
                Preset(name: "Cool Keyboard (Balanced Surface)", description: "Ramps fans up earlier to keep keyboard and palmrest cool to the touch.", minTemp: 32.0, maxTemp: 40.0),
                Preset(name: "Max Surface Cooling (Aggressive)", description: "Aggressively cools surface even at lower ambient temps.", minTemp: 28.0, maxTemp: 35.0)
            ]
        case .cpu, .gpu:
            presets = [
                Preset(name: "Quiet Curve", description: "Minimal fan noise; allows chip to run warmer before ramping fans.", minTemp: 55.0, maxTemp: 85.0),
                Preset(name: "Balanced Curve (Recommended)", description: "Standard balance between acoustic comfort and thermal performance.", minTemp: 48.0, maxTemp: 80.0),
                Preset(name: "Performance / Gaming", description: "Ramps fans early to maintain low chip temps and max boost clocks.", minTemp: 40.0, maxTemp: 70.0)
            ]
        case .battery:
            presets = [
                Preset(name: "Balanced Battery Protection", description: "Keeps battery at safe health temperatures.", minTemp: 30.0, maxTemp: 40.0),
                Preset(name: "Aggressive Battery Cooling", description: "Prioritizes low battery temperatures while charging.", minTemp: 28.0, maxTemp: 35.0)
            ]
        case .storage:
            presets = [
                Preset(name: "SSD Protection (Balanced)", description: "Prevents thermal throttling on fast NVMe drives.", minTemp: 40.0, maxTemp: 55.0)
            ]
        default:
            presets = [
                Preset(name: "Standard Balanced Curve", description: "Default temperature response curve.", minTemp: 45.0, maxTemp: 75.0)
            ]
        }

        for (idx, p) in presets.enumerated() {
            print("  [\(idx + 1)] \(p.name)\n      \(TerminalUI.gray)\(p.description)\(TerminalUI.reset)")
            print("      Temp Range: \(TerminalUI.cyan)\(p.minTemp)°C\(TerminalUI.reset) (min speed) → \(TerminalUI.cyan)\(p.maxTemp)°C\(TerminalUI.reset) (max speed)")
        }
        print("  [\(presets.count + 1)] Custom Temperatures & RPM Limits")

        let presetChoice = promptInt(prompt: "Select Curve Profile", minVal: 1, maxVal: presets.count + 1, defaultVal: 1)

        var finalMinTemp: Double
        var finalMaxTemp: Double
        var finalMinRPM: Double = defaultMinRPM
        var finalMaxRPM: Double = defaultMaxRPM

        if presetChoice <= presets.count {
            let p = presets[presetChoice - 1]
            finalMinTemp = p.minTemp
            finalMaxTemp = p.maxTemp
        } else {
            // Custom setup
            TerminalUI.printSection("Custom Temperature & RPM Configuration")
            finalMinTemp = promptDouble(prompt: "Min Temperature (°C) [fan starts ramping above this]", defaultVal: activeTemp - 2.0 > 20.0 ? activeTemp - 2.0 : 30.0)
            finalMaxTemp = promptDouble(prompt: "Max Temperature (°C) [fan reaches max RPM at this]", defaultVal: finalMinTemp + 15.0)

            print("\n  Hardware RPM limits: Min \(Int(defaultMinRPM)) RPM | Max \(Int(defaultMaxRPM)) RPM")
            finalMinRPM = promptDouble(prompt: "Min Fan Speed (RPM)", defaultVal: defaultMinRPM)
            finalMaxRPM = promptDouble(prompt: "Max Fan Speed (RPM)", defaultVal: defaultMaxRPM)
        }

        // 4. Select Curve Shape / Transfer Function
        TerminalUI.printSection("Step 4: Select Curve Shape (Response Profile)")
        print("  [1] Linear Ramp       [ / ]  Standard proportional linear response")
        print("  [2] Quiet Exponential [ __/ ] Stays whisper-quiet longer, ramps up at higher temps")
        print("  [3] Aggressive        [ /‾ ] Ramps fan speed early for low core temperatures")
        print("  [4] S-Curve (Smooth)  [ _/~ ] Smooth acceleration and deceleration")
        print("  [5] Stepped Curve     [ _|- ] Discrete speed stages (prevents RPM oscillation)")
        print("  [6] Custom Multi-Point[ •-• ] Explicit temperature control points (GUI ready)")

        let shapeChoice = promptInt(prompt: "Select Curve Shape", minVal: 1, maxVal: 6, defaultVal: 1)

        var finalShape: CurveShape = .linear
        var customPoints: [CurvePoint] = []

        switch shapeChoice {
        case 1: finalShape = .linear
        case 2: finalShape = .quiet
        case 3: finalShape = .aggressive
        case 4: finalShape = .sCurve
        case 5: finalShape = .stepped
        case 6:
            // Custom multi-points
            TerminalUI.printSection("Custom Control Points Setup")
            print("Define control points in format: temp:rpm or temp:% (e.g. 30:2317, 45:3500, 60:5500, 75:7826)")
            print("Example percentage format: 30:20%, 45:40%, 60:75%, 75:100%\n")
            print("Enter control points: ", terminator: "")
            fflush(stdout)
            if let line = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !line.isEmpty {
                customPoints = CurveCommand.parsePoints(line)
            }
            if customPoints.isEmpty {
                print("\(TerminalUI.yellow)No valid points entered. Defaulting to 4 generated control points.\(TerminalUI.reset)")
            }
        default: break
        }

        // Build config object & generate UI-compatible point preview
        let config = FanCurveConfig(
            fanId: selectedFanId,
            sensorCategory: chosenCategory,
            sensorId: chosenSensorId,
            minTemp: finalMinTemp,
            maxTemp: finalMaxTemp,
            minRPM: finalMinRPM,
            maxRPM: finalMaxRPM,
            shape: finalShape,
            points: customPoints
        )

        let previewPoints = config.generatePoints(count: 5, minHardwareRPM: defaultMinRPM, maxHardwareRPM: defaultMaxRPM)

        // 5. Confirmation & Execution
        TerminalUI.printSection("Summary & Launch")
        let fanTargetStr = selectedFanId != nil ? "Fan \(selectedFanId!)" : "All Fans"
        let sensorTargetStr = chosenSensorId != nil ? "Sensor '\(sensorDisplayName)'" : "\(chosenCategory.rawValue) Category"

        print("  • Target Fan(s) : \(TerminalUI.bold)\(fanTargetStr)\(TerminalUI.reset)")
        print("  • Sensor Target : \(TerminalUI.bold)\(sensorTargetStr)\(TerminalUI.reset)")
        print("  • Temp Threshold: \(TerminalUI.cyan)\(finalMinTemp)°C\(TerminalUI.reset) → \(TerminalUI.cyan)\(finalMaxTemp)°C\(TerminalUI.reset)")
        print("  • RPM Range     : \(Int(finalMinRPM)) RPM → \(Int(finalMaxRPM)) RPM")
        if !customPoints.isEmpty {
            print("  • Curve Mode    : \(TerminalUI.bold)Multi-Point Custom (\(customPoints.count) points)\(TerminalUI.reset)")
        } else {
            print("  • Response Shape: \(TerminalUI.bold)\(finalShape.displayName)\(TerminalUI.reset)")
        }

        print("\n  \(TerminalUI.bold)Generated Control Points (GUI Compatible):\(TerminalUI.reset)")
        for (idx, pt) in previewPoints.enumerated() {
            let rpmVal = pt.resolveRPM(minRPM: finalMinRPM, maxRPM: finalMaxRPM)
            let pct = pt.rpmPercentage ?? (((rpmVal - defaultMinRPM) / (defaultMaxRPM - defaultMinRPM)) * 100.0)
            print(String(format: "    Point %d: %5.1f°C ➔ %5d RPM (%3.0f%%)", idx + 1, pt.tempCelsius, Int(rpmVal), pct))
        }

        // Build command line equivalent
        var cmdArgs: [String] = ["fancontrol", "curve"]
        if let fid = selectedFanId { cmdArgs.append(contentsOf: ["--fan", "\(fid)"]) }
        if let sid = chosenSensorId {
            cmdArgs.append(contentsOf: ["--sensor", sid])
        } else {
            cmdArgs.append(contentsOf: ["--sensor", chosenCategory.rawValue.lowercased()])
        }

        if !customPoints.isEmpty {
            let ptsArg = customPoints.map { pt in
                if let p = pt.rpmPercentage { return "\(pt.tempCelsius):\(Int(p))%" }
                if let r = pt.rpmValue { return "\(pt.tempCelsius):\(Int(r))" }
                return "\(pt.tempCelsius)"
            }.joined(separator: ",")
            cmdArgs.append(contentsOf: ["--points", ptsArg])
        } else {
            cmdArgs.append(contentsOf: [
                "--min-temp", String(format: "%.1f", finalMinTemp),
                "--max-temp", String(format: "%.1f", finalMaxTemp),
                "--min-rpm", "\(Int(finalMinRPM))",
                "--max-rpm", "\(Int(finalMaxRPM))",
                "--shape", finalShape.rawValue
            ])
        }

        let fullCmd = "sudo " + cmdArgs.joined(separator: " ")
        print("\nEquivalent Command Line:\n  \(TerminalUI.bold)\(TerminalUI.cyan)\(fullCmd) --background\(TerminalUI.reset)\n")

        print("What would you like to do?")
        print("  [1] Start in background daemon mode (frees terminal prompt)")
        print("  [2] Start in foreground mode (live interactive terminal monitoring)")
        print("  [3] Exit (I will run the command manually)")

        let execChoice = promptInt(prompt: "Select Action", minVal: 1, maxVal: 3, defaultVal: 1)

        if execChoice == 1 {
            var bgArgs = Array(cmdArgs.dropFirst(2))
            bgArgs.append("--background")
            CurveCommand.run(args: bgArgs)
        } else if execChoice == 2 {
            print("\nStarting Fan Curve Daemon in foreground...\n")
            let subArgs = Array(cmdArgs.dropFirst(2))
            CurveCommand.run(args: subArgs)
        } else {
            print("Wizard completed. Copy the command above to launch your curve at any time.")
        }
    }

    private static func promptInt(prompt: String, minVal: Int, maxVal: Int, defaultVal: Int) -> Int {
        while true {
            print("\(prompt) [\(minVal)-\(maxVal)] (default: \(defaultVal)): ", terminator: "")
            fflush(stdout)
            guard let line = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !line.isEmpty else {
                return defaultVal
            }
            if let val = Int(line), val >= minVal && val <= maxVal {
                return val
            }
            print("\(TerminalUI.red)Invalid selection. Please enter a number between \(minVal) and \(maxVal).\(TerminalUI.reset)")
        }
    }

    private static func promptDouble(prompt: String, defaultVal: Double) -> Double {
        while true {
            print("\(prompt) (default: \(String(format: "%.1f", defaultVal))): ", terminator: "")
            fflush(stdout)
            guard let line = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !line.isEmpty else {
                return defaultVal
            }
            if let val = Double(line) {
                return val
            }
            print("\(TerminalUI.red)Invalid number. Please enter a valid decimal number.\(TerminalUI.reset)")
        }
    }
}
