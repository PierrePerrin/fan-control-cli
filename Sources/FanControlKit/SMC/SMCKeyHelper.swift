import Foundation

public struct SMCKeyHelper {
    public static let fanCountKey = "FNum"

    public static func actualSpeedKey(for fanId: Int) -> String {
        return "F\(fanId)Ac"
    }

    public static func targetSpeedKey(for fanId: Int) -> String {
        return "F\(fanId)Tg"
    }

    public static func minSpeedKey(for fanId: Int) -> String {
        return "F\(fanId)Mn"
    }

    public static func maxSpeedKey(for fanId: Int) -> String {
        return "F\(fanId)Mx"
    }

    public static func fanModeKey(for fanId: Int) -> String {
        return "F\(fanId)Md"
    }

    public static func fanIDKey(for fanId: Int) -> String {
        return "F\(fanId)ID"
    }

    public static func defaultFanName(for fanId: Int, totalFans: Int) -> String {
        if totalFans == 1 {
            return "Main Fan"
        } else if totalFans == 2 {
            return fanId == 0 ? "Left Fan" : "Right Fan"
        } else {
            return "Fan \(fanId)"
        }
    }

    public static func categorizeKey(_ key: String) -> (name: String, category: SensorCategory)? {
        if let info = knownKeyTable[key] {
            return info
        }

        // Dynamic Apple Silicon key categorization
        guard key.hasPrefix("T") && key.count == 4 else { return nil }

        let secondChar = key[key.index(after: key.startIndex)]
        switch secondChar {
        case "p":
            return ("CPU Performance Core (\(key))", .cpu)
        case "e":
            return ("CPU Efficiency Core (\(key))", .cpu)
        case "c", "C":
            return ("CPU Core (\(key))", .cpu)
        case "g", "G":
            return ("GPU Cluster (\(key))", .gpu)
        case "a", "A":
            return ("Thermal Zone (\(key))", .ambient)
        case "b", "B":
            return ("Battery Sensor (\(key))", .battery)
        case "h", "H", "N":
            return ("Storage Sensor (\(key))", .storage)
        case "f", "s", "S", "u", "U", "V", "R":
            return ("System / SoC (\(key))", .system)
        default:
            return ("Thermal Sensor (\(key))", .other)
        }
    }

    public static let knownKeyTable: [String: (name: String, category: SensorCategory)] = [
        // Intel CPU
        "TC0P": ("CPU Proximity", .cpu),
        "TC0D": ("CPU Die", .cpu),
        "TC0E": ("CPU Core 1", .cpu),
        "TC0F": ("CPU Core 2", .cpu),
        "TC1C": ("CPU Core 1", .cpu),
        "TC2C": ("CPU Core 2", .cpu),
        "TC3C": ("CPU Core 3", .cpu),
        "TC4C": ("CPU Core 4", .cpu),
        "TCAH": ("CPU Core (Heatsink)", .cpu),
        "TCXC": ("CPU Core PEK", .cpu),
        
        // Intel GPU
        "TG0P": ("GPU Proximity", .gpu),
        "TG0D": ("GPU Die", .gpu),
        "TG1D": ("GPU Die 2", .gpu),
        
        // Memory / Storage
        "TM0P": ("Memory Proximity", .system),
        "TM0S": ("Memory Slot 1", .system),
        "TH0P": ("Storage Proximity", .storage),
        "TB0T": ("Battery TS_MAX", .battery),
        "TB1T": ("Battery 1", .battery),
        "TB2T": ("Battery 2", .battery),
        
        // Ambient / Enclosure
        "TA0P": ("Ambient Air", .ambient),
        "TA1P": ("Ambient Air 2", .ambient),
        "TaLP": ("Left Palm Rest", .ambient),
        "TaRF": ("Right Palm Rest", .ambient),
        "TaTP": ("Trackpad Area", .ambient),
        "TW0P": ("Wireless Airflow", .ambient)
    ]
}
