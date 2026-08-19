import Foundation

public enum SensorCategory: String, Codable, Sendable, CaseIterable, CustomStringConvertible {
    case cpu = "CPU"
    case gpu = "GPU"
    case battery = "Battery"
    case storage = "Storage"
    case ambient = "Ambient"
    case system = "System"
    case other = "Other"

    public var description: String { rawValue }
}

public struct ThermalSensor: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let category: SensorCategory
    public var temperatureCelsius: Double

    public var temperatureFahrenheit: Double {
        return (temperatureCelsius * 9.0 / 5.0) + 32.0
    }

    public init(
        id: String,
        name: String,
        category: SensorCategory,
        temperatureCelsius: Double
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.temperatureCelsius = temperatureCelsius
    }
}
