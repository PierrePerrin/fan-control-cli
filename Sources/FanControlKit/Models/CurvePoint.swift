import Foundation

public enum CurveShape: String, Codable, Sendable, CaseIterable, CustomStringConvertible {
    case linear = "linear"
    case quiet = "quiet"
    case aggressive = "aggressive"
    case sCurve = "scurve"
    case stepped = "stepped"

    public var description: String { rawValue }

    public var displayName: String {
        switch self {
        case .linear: return "Linear Ramp"
        case .quiet: return "Quiet Exponential (Stays quiet longer)"
        case .aggressive: return "Aggressive Cooling (Ramps early)"
        case .sCurve: return "S-Curve (Sigmoid smooth transitions)"
        case .stepped: return "Stepped (Discrete speed stages)"
        }
    }
}

public struct CurvePoint: Codable, Sendable, Equatable, Comparable {
    public var tempCelsius: Double
    public var rpmPercentage: Double? // 0.0 to 100.0%
    public var rpmValue: Double?      // Absolute RPM

    public init(tempCelsius: Double, rpmPercentage: Double) {
        self.tempCelsius = tempCelsius
        self.rpmPercentage = rpmPercentage
        self.rpmValue = nil
    }

    public init(tempCelsius: Double, rpmValue: Double) {
        self.tempCelsius = tempCelsius
        self.rpmPercentage = nil
        self.rpmValue = rpmValue
    }

    public static func < (lhs: CurvePoint, rhs: CurvePoint) -> Bool {
        return lhs.tempCelsius < rhs.tempCelsius
    }

    public func resolveRPM(minRPM: Double, maxRPM: Double) -> Double {
        if let val = rpmValue {
            return max(minRPM, min(maxRPM, val))
        }
        if let pct = rpmPercentage {
            let clampedPct = max(0.0, min(100.0, pct)) / 100.0
            return minRPM + clampedPct * (maxRPM - minRPM)
        }
        return minRPM
    }
}
