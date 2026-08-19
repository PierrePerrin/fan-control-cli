import Foundation

public enum FanMode: String, Codable, Sendable, CaseIterable, CustomStringConvertible {
    case auto = "Auto"
    case manual = "Manual"

    public var description: String { rawValue }
}

public struct Fan: Codable, Sendable, Identifiable, Equatable {
    public let id: Int
    public let name: String
    public var currentRPM: Double
    public var targetRPM: Double
    public var minRPM: Double
    public var maxRPM: Double
    public var mode: FanMode

    public var percentage: Double {
        guard maxRPM > minRPM else { return 0.0 }
        let clamped = max(minRPM, min(currentRPM, maxRPM))
        return ((clamped - minRPM) / (maxRPM - minRPM)) * 100.0
    }

    public var targetPercentage: Double {
        guard maxRPM > minRPM else { return 0.0 }
        let clamped = max(minRPM, min(targetRPM, maxRPM))
        return ((clamped - minRPM) / (maxRPM - minRPM)) * 100.0
    }

    public init(
        id: Int,
        name: String,
        currentRPM: Double,
        targetRPM: Double,
        minRPM: Double,
        maxRPM: Double,
        mode: FanMode
    ) {
        self.id = id
        self.name = name
        self.currentRPM = currentRPM
        self.targetRPM = targetRPM
        self.minRPM = minRPM
        self.maxRPM = maxRPM
        self.mode = mode
    }
}
