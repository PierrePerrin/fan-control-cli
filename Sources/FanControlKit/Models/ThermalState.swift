import Foundation

public struct ThermalState: Codable, Sendable {
    public let timestamp: Date
    public let fans: [Fan]
    public let sensors: [ThermalSensor]

    public var cpuAverageTemp: Double? {
        let cpuSensors = sensors.filter { $0.category == .cpu && $0.temperatureCelsius > 15.0 && $0.temperatureCelsius < 125.0 }
        guard !cpuSensors.isEmpty else { return nil }
        let total = cpuSensors.reduce(0.0) { $0 + $1.temperatureCelsius }
        return total / Double(cpuSensors.count)
    }

    public var cpuMaxTemp: Double? {
        let cpuSensors = sensors.filter { $0.category == .cpu && $0.temperatureCelsius > 15.0 && $0.temperatureCelsius < 125.0 }
        return cpuSensors.map(\.temperatureCelsius).max()
    }

    public var gpuAverageTemp: Double? {
        let gpuSensors = sensors.filter { $0.category == .gpu && $0.temperatureCelsius > 15.0 && $0.temperatureCelsius < 125.0 }
        guard !gpuSensors.isEmpty else { return nil }
        let total = gpuSensors.reduce(0.0) { $0 + $1.temperatureCelsius }
        return total / Double(gpuSensors.count)
    }

    public var gpuMaxTemp: Double? {
        let gpuSensors = sensors.filter { $0.category == .gpu && $0.temperatureCelsius > 15.0 && $0.temperatureCelsius < 125.0 }
        return gpuSensors.map(\.temperatureCelsius).max()
    }

    public var batteryTemp: Double? {
        let batterySensors = sensors.filter { $0.category == .battery && $0.temperatureCelsius > 0.0 && $0.temperatureCelsius < 80.0 }
        guard !batterySensors.isEmpty else { return nil }
        return batterySensors.map(\.temperatureCelsius).max()
    }

    public var ambientTemp: Double? {
        let ambientSensors = sensors.filter { $0.category == .ambient && $0.temperatureCelsius > 0.0 && $0.temperatureCelsius < 80.0 }
        guard !ambientSensors.isEmpty else { return nil }
        let total = ambientSensors.reduce(0.0) { $0 + $1.temperatureCelsius }
        return total / Double(ambientSensors.count)
    }

    public init(
        timestamp: Date = Date(),
        fans: [Fan],
        sensors: [ThermalSensor]
    ) {
        self.timestamp = timestamp
        self.fans = fans
        self.sensors = sensors
    }
}
