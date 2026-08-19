import Foundation

public final class SensorManager: @unchecked Sendable {
    public static let shared = SensorManager()

    private let smc = SMCService.shared
    private let hid = HIDThermalClient.shared

    // Fast targeted list of common SMC temperature keys for Intel & Apple Silicon
    private static let commonSMCKeys: [String] = [
        // Intel
        "TC0P", "TC0D", "TC0E", "TC0F", "TC1C", "TC2C", "TC3C", "TC4C", "TCAH", "TCXC",
        "TG0P", "TG0D", "TG1D", "TM0P", "TM0S", "TH0P", "TB0T", "TB1T", "TB2T", "TA0P", "TA1P",
        "TW0P", "TaLP", "TaRF", "TaTP",
        // Apple Silicon
        "Tp01", "Tp05", "Tp09", "Tp0D", "Tp1i", "Tp1j", "Tp1k", "Tp1m", "Tp1n", "Tp1o",
        "Tp20", "Tp21", "Tp22", "Tp23", "Tp24", "Tp25", "Tp26", "Tp27", "Tp28", "Tp29",
        "Te04", "Te05", "Te06", "Te0R", "Te0S", "Te0T", "Tex0", "Tex1", "Tex2", "Tex3",
        "Tg04", "Tg05", "Tg0K", "Tg0L", "Tg0R", "Tg0S", "Tg0X", "Tg0Y", "Tg1E", "Tg1F",
        "TfC0", "TfC1", "TfC2", "TfC3", "TfC4", "Ts00", "Ts01", "Ts02", "Ts04", "Ts05",
        "Ts0P", "Ts1P", "Tsx0", "Tsx1", "TVD0", "TVMR", "TVMX", "TVMr", "TVMx", "TVh0"
    ]

    private init() {}

    public func discoverSensors() -> [ThermalSensor] {
        var sensors: [ThermalSensor] = []
        var seenNames = Set<String>()

        // 1. Read HID named sensors (instant and named on macOS)
        let hidSensors = hid.readSensors()
        for sensor in hidSensors {
            if !seenNames.contains(sensor.name) {
                seenNames.insert(sensor.name)
                sensors.append(sensor)
            }
        }

        // 2. Read targeted SMC temperature sensors
        for key in Self.commonSMCKeys {
            if let temp = try? smc.readFloat(key: key) {
                let dTemp = Double(temp)
                if dTemp > 10.0 && dTemp < 125.0 {
                    if let (name, category) = SMCKeyHelper.categorizeKey(key) {
                        let id = "SMC_\(key)"
                        if !seenNames.contains(name) {
                            seenNames.insert(name)
                            sensors.append(ThermalSensor(
                                id: id,
                                name: name,
                                category: category,
                                temperatureCelsius: dTemp
                            ))
                        }
                    }
                }
            }
        }

        // Sort by category then by name
        return sensors.sorted { s1, s2 in
            if s1.category.rawValue != s2.category.rawValue {
                return s1.category.rawValue < s2.category.rawValue
            }
            return s1.name < s2.name
        }
    }

    public func getSensors(in category: SensorCategory) -> [ThermalSensor] {
        return discoverSensors().filter { $0.category == category }
    }
}
