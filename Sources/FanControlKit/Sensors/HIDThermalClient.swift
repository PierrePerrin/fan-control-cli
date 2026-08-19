import Foundation
import SMCBridge

public final class HIDThermalClient: @unchecked Sendable {
    public static let shared = HIDThermalClient()

    private init() {}

    public func readSensors() -> [ThermalSensor] {
        let maxCount = 128
        var sensors = [SMCHIDSensor](repeating: SMCHIDSensor(name: (0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0), temperature: 0), count: maxCount)
        
        let count = sensors.withUnsafeMutableBufferPointer { ptr in
            smc_read_hid_sensors(ptr.baseAddress, Int32(maxCount))
        }

        guard count > 0 else { return [] }

        var result: [ThermalSensor] = []
        for i in 0..<Int(count) {
            let item = sensors[i]
            let name = withUnsafeBytes(of: item.name) { ptr in
                String(cString: ptr.baseAddress!.assumingMemoryBound(to: CChar.self))
            }.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !name.isEmpty else { continue }
            let temp = Double(item.temperature)

            // Categorize HID sensor name
            let category = categorizeHIDName(name)
            let sensor = ThermalSensor(
                id: "HID_\(name.replacingOccurrences(of: " ", with: "_"))",
                name: name,
                category: category,
                temperatureCelsius: temp
            )
            result.append(sensor)
        }

        return result
    }

    private func categorizeHIDName(_ name: String) -> SensorCategory {
        let lower = name.lowercased()
        if lower.contains("cpu") || lower.contains("tdie") || lower.contains("pcore") || lower.contains("ecore") {
            return .cpu
        } else if lower.contains("gpu") {
            return .gpu
        } else if lower.contains("battery") || lower.contains("gas gauge") {
            return .battery
        } else if lower.contains("nand") || lower.contains("drive") || lower.contains("storage") {
            return .storage
        } else if lower.contains("ambient") || lower.contains("air") || lower.contains("skin") || lower.contains("palm") {
            return .ambient
        } else {
            return .system
        }
    }
}
