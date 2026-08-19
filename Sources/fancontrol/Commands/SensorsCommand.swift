import Foundation
import FanControlKit

public struct SensorsCommand {
    public static func run(args: [String], isJSON: Bool, unit: String = "C") {
        var filterCategory: SensorCategory? = nil
        var currentUnit = unit

        var i = 0
        while i < args.count {
            let arg = args[i]
            if (arg == "--category" || arg == "-c") && i + 1 < args.count {
                let catStr = args[i + 1].lowercased()
                if catStr == "cpu" { filterCategory = .cpu }
                else if catStr == "gpu" { filterCategory = .gpu }
                else if catStr == "battery" { filterCategory = .battery }
                else if catStr == "storage" { filterCategory = .storage }
                else if catStr == "ambient" { filterCategory = .ambient }
                else if catStr == "system" { filterCategory = .system }
                else if catStr == "all" { filterCategory = nil }
                i += 1
            } else if (arg == "--unit" || arg == "-u") && i + 1 < args.count {
                currentUnit = args[i + 1]
                i += 1
            }
            i += 1
        }

        var sensors = SensorManager.shared.discoverSensors()
        if let filter = filterCategory {
            sensors = sensors.filter { $0.category == filter }
        }

        if isJSON {
            print(JSONFormatter.encode(sensors))
            return
        }

        TerminalUI.printHeader("Hardware Thermal Sensors")

        if sensors.isEmpty {
            print("  \(TerminalUI.gray)No matching sensors found.\(TerminalUI.reset)")
            return
        }

        let grouped = Dictionary(grouping: sensors, by: { $0.category })
        let categoriesOrder: [SensorCategory] = [.cpu, .gpu, .battery, .storage, .ambient, .system, .other]

        for cat in categoriesOrder {
            guard let catSensors = grouped[cat], !catSensors.isEmpty else { continue }
            TerminalUI.printSection("\(cat.rawValue) Sensors (\(catSensors.count))")
            print("  \(TerminalUI.bold)\(TerminalUI.gray)Sensor Name                             Key / ID                Temperature\(TerminalUI.reset)")
            print("  \(TerminalUI.gray)-----------------------------------------------------------------------\(TerminalUI.reset)")

            for s in catSensors {
                let formattedTemp = TerminalUI.formatTemperature(s.temperatureCelsius, unit: currentUnit)
                let namePad = s.name.padding(toLength: 38, withPad: " ", startingAt: 0)
                let idPad = s.id.padding(toLength: 22, withPad: " ", startingAt: 0)
                print("  \(namePad)  \(TerminalUI.gray)\(idPad)\(TerminalUI.reset)  \(formattedTemp)")
            }
        }
    }
}
