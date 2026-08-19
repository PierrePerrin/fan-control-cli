import Foundation

public struct FanCurveConfig: Sendable {
    public var fanId: Int? // nil means all fans
    public var sensorCategory: SensorCategory
    public var sensorId: String? // nil means hottest in category
    public var minTemp: Double
    public var maxTemp: Double
    public var minRPM: Double?
    public var maxRPM: Double?
    public var shape: CurveShape
    public var points: [CurvePoint]

    public init(
        fanId: Int? = nil,
        sensorCategory: SensorCategory = .cpu,
        sensorId: String? = nil,
        minTemp: Double = 45.0,
        maxTemp: Double = 85.0,
        minRPM: Double? = nil,
        maxRPM: Double? = nil,
        shape: CurveShape = .linear,
        points: [CurvePoint] = []
    ) {
        self.fanId = fanId
        self.sensorCategory = sensorCategory
        self.sensorId = sensorId
        self.minTemp = minTemp
        self.maxTemp = maxTemp
        self.minRPM = minRPM
        self.maxRPM = maxRPM
        self.shape = shape
        self.points = points.sorted()
    }

    /// Generates control points representation of the curve suitable for GUI visualization.
    public func generatePoints(count: Int = 5, minHardwareRPM: Double = 2000.0, maxHardwareRPM: Double = 6000.0) -> [CurvePoint] {
        if !points.isEmpty {
            return points.sorted()
        }

        let effectiveMinRPM = minRPM ?? minHardwareRPM
        let effectiveMaxRPM = maxRPM ?? maxHardwareRPM
        let steps = max(2, count)
        var result: [CurvePoint] = []

        for i in 0..<steps {
            let t = Double(i) / Double(steps - 1)
            let temp = minTemp + t * (maxTemp - minTemp)
            let ratio: Double
            switch shape {
            case .linear:
                ratio = t
            case .quiet:
                ratio = pow(t, 2.2)
            case .aggressive:
                ratio = sqrt(t)
            case .sCurve:
                ratio = t * t * (3.0 - 2.0 * t)
            case .stepped:
                ratio = floor(t * 4.0) / 3.0
            }
            let clampedRatio = max(0.0, min(1.0, ratio))
            let rpm = effectiveMinRPM + clampedRatio * (effectiveMaxRPM - effectiveMinRPM)
            let pct = ((rpm - minHardwareRPM) / (maxHardwareRPM - minHardwareRPM)) * 100.0
            result.append(CurvePoint(tempCelsius: temp, rpmPercentage: pct))
        }

        return result
    }
}

public final class FanCurveController: @unchecked Sendable {
    public let config: FanCurveConfig
    private let fanManager: FanManager
    private let sensorManager: SensorManager

    public init(
        config: FanCurveConfig,
        fanManager: FanManager = .shared,
        sensorManager: SensorManager = .shared
    ) {
        self.config = config
        self.fanManager = fanManager
        self.sensorManager = sensorManager
    }

    public func calculateTargetRPM(currentTemp: Double, fan: Fan) -> Double {
        let minR = max(fan.minRPM, config.minRPM ?? fan.minRPM)
        let maxR = min(fan.maxRPM, config.maxRPM ?? fan.maxRPM)

        // 1. Point-based multi-point evaluation (GUI ready)
        if !config.points.isEmpty {
            let sortedPoints = config.points.sorted()
            if currentTemp <= sortedPoints.first!.tempCelsius {
                return sortedPoints.first!.resolveRPM(minRPM: minR, maxRPM: maxR)
            }
            if currentTemp >= sortedPoints.last!.tempCelsius {
                return sortedPoints.last!.resolveRPM(minRPM: minR, maxRPM: maxR)
            }

            for i in 0..<(sortedPoints.count - 1) {
                let p1 = sortedPoints[i]
                let p2 = sortedPoints[i + 1]
                if currentTemp >= p1.tempCelsius && currentTemp <= p2.tempCelsius {
                    let range = p2.tempCelsius - p1.tempCelsius
                    let t = range > 0 ? (currentTemp - p1.tempCelsius) / range : 0.0
                    let rpm1 = p1.resolveRPM(minRPM: minR, maxRPM: maxR)
                    let rpm2 = p2.resolveRPM(minRPM: minR, maxRPM: maxR)
                    let interpolated = rpm1 + t * (rpm2 - rpm1)
                    return max(fan.minRPM, min(fan.maxRPM, interpolated))
                }
            }
        }

        // 2. Continuous transfer function shape evaluation
        let target: Double
        if currentTemp <= config.minTemp {
            target = minR
        } else if currentTemp >= config.maxTemp {
            target = maxR
        } else {
            let t = (currentTemp - config.minTemp) / (config.maxTemp - config.minTemp)
            let ratio: Double
            switch config.shape {
            case .linear:
                ratio = t
            case .quiet:
                ratio = pow(t, 2.2)
            case .aggressive:
                ratio = sqrt(t)
            case .sCurve:
                ratio = t * t * (3.0 - 2.0 * t)
            case .stepped:
                ratio = floor(t * 4.0) / 3.0
            }
            let clampedRatio = max(0.0, min(1.0, ratio))
            target = minR + clampedRatio * (maxR - minR)
        }

        return max(fan.minRPM, min(fan.maxRPM, target))
    }


    public func getActiveSensor() -> ThermalSensor? {
        let allSensors = sensorManager.discoverSensors()

        // 1. If a specific sensor ID or name is requested
        if let targetId = config.sensorId?.lowercased() {
            if let matched = allSensors.first(where: {
                $0.id.lowercased() == targetId ||
                $0.id.lowercased() == "smc_\(targetId)" ||
                $0.name.lowercased().contains(targetId)
            }) {
                return matched
            }
        }

        // 2. Otherwise find the hottest sensor in the specified category
        let categorySensors = allSensors.filter { $0.category == config.sensorCategory && $0.temperatureCelsius > 10.0 && $0.temperatureCelsius < 125.0 }
        return categorySensors.max(by: { $0.temperatureCelsius < $1.temperatureCelsius })
    }

    @discardableResult
    public func evaluateAndApply() throws -> (temp: Double, sensor: ThermalSensor, appliedRPM: [Int: Double]) {
        guard let activeSensor = getActiveSensor() else {
            throw SMCError.invalidArgument("No sensors found matching category '\(config.sensorCategory.rawValue)' or ID '\(config.sensorId ?? "")'")
        }

        let currentTemp = activeSensor.temperatureCelsius
        let fans = fanManager.getFans()
        var applied: [Int: Double] = [:]

        for fan in fans {
            if config.fanId == nil || config.fanId == fan.id {
                let targetRPM = calculateTargetRPM(currentTemp: currentTemp, fan: fan)
                try fanManager.setFanSpeed(fanId: fan.id, targetRPM: targetRPM)
                applied[fan.id] = targetRPM
            }
        }

        return (currentTemp, activeSensor, applied)
    }
}
