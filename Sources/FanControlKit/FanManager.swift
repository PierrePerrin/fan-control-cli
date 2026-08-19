import Foundation

public final class FanManager: @unchecked Sendable {
    public static let shared = FanManager()

    private let smc = SMCService.shared
    private let sensorManager = SensorManager.shared

    private init() {}

    public func getFanCount() -> Int {
        if let count = try? smc.readUInt8(key: SMCKeyHelper.fanCountKey) {
            return Int(count)
        }
        return 0
    }

    public func getFans() -> [Fan] {
        let count = getFanCount()
        guard count > 0 else { return [] }

        var fans: [Fan] = []
        for i in 0..<count {
            let actualKey = SMCKeyHelper.actualSpeedKey(for: i)
            let minKey = SMCKeyHelper.minSpeedKey(for: i)
            let maxKey = SMCKeyHelper.maxSpeedKey(for: i)
            let targetKey = SMCKeyHelper.targetSpeedKey(for: i)
            let modeKey = SMCKeyHelper.fanModeKey(for: i)

            let currentRPM = (try? smc.readFloat(key: actualKey)).map(Double.init) ?? 0.0
            let minRPM = (try? smc.readFloat(key: minKey)).map(Double.init) ?? 1000.0
            let maxRPM = (try? smc.readFloat(key: maxKey)).map(Double.init) ?? 6000.0
            let targetRPM = (try? smc.readFloat(key: targetKey)).map(Double.init) ?? currentRPM
            let modeVal = (try? smc.readUInt8(key: modeKey)) ?? 0


            let mode: FanMode = (modeVal == 1) ? .manual : .auto
            let name = SMCKeyHelper.defaultFanName(for: i, totalFans: count)

            fans.append(Fan(
                id: i,
                name: name,
                currentRPM: currentRPM,
                targetRPM: targetRPM,
                minRPM: minRPM,
                maxRPM: maxRPM,
                mode: mode
            ))
        }

        return fans
    }

    public func getFan(id: Int) -> Fan? {
        let fans = getFans()
        return fans.first { $0.id == id }
    }

    public func setFanSpeed(fanId: Int, targetRPM: Double) throws {
        guard let fan = getFan(id: fanId) else {
            throw SMCError.invalidArgument("Fan with ID \(fanId) not found.")
        }

        // Clamp automatically to hardware bounds
        let clampedRPM = max(fan.minRPM, min(fan.maxRPM, targetRPM))

        let modeKey = SMCKeyHelper.fanModeKey(for: fanId)
        let targetKey = SMCKeyHelper.targetSpeedKey(for: fanId)

        // Set mode to manual (1)
        try smc.writeUInt8(key: modeKey, value: 1)

        // Set target speed
        try smc.writeFloat(key: targetKey, value: Float(clampedRPM))
    }


    public func setFanPercentage(fanId: Int, percentage: Double) throws {
        guard let fan = getFan(id: fanId) else {
            throw SMCError.invalidArgument("Fan with ID \(fanId) not found.")
        }

        let clamped = max(0.0, min(100.0, percentage))
        let targetRPM = fan.minRPM + (clamped / 100.0) * (fan.maxRPM - fan.minRPM)
        try setFanSpeed(fanId: fanId, targetRPM: targetRPM)
    }

    public func setFanMode(fanId: Int, mode: FanMode) throws {
        guard let _ = getFan(id: fanId) else {
            throw SMCError.invalidArgument("Fan with ID \(fanId) not found.")
        }

        let modeKey = SMCKeyHelper.fanModeKey(for: fanId)
        let modeValue: UInt8 = (mode == .manual) ? 1 : 0
        try smc.writeUInt8(key: modeKey, value: modeValue)
    }

    public func resetAllToAuto() throws {
        let count = getFanCount()
        for i in 0..<count {
            let modeKey = SMCKeyHelper.fanModeKey(for: i)
            try smc.writeUInt8(key: modeKey, value: 0)
        }
    }

    public func getThermalState() -> ThermalState {
        let fans = getFans()
        let sensors = sensorManager.discoverSensors()
        return ThermalState(fans: fans, sensors: sensors)
    }
}
