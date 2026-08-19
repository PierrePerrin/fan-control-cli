import XCTest
@testable import FanControlKit

final class SMCKeyTests: XCTestCase {
    func testKeyHelperKeys() {
        XCTAssertEqual(SMCKeyHelper.fanCountKey, "FNum")
        XCTAssertEqual(SMCKeyHelper.actualSpeedKey(for: 0), "F0Ac")
        XCTAssertEqual(SMCKeyHelper.actualSpeedKey(for: 1), "F1Ac")
        XCTAssertEqual(SMCKeyHelper.targetSpeedKey(for: 0), "F0Tg")
        XCTAssertEqual(SMCKeyHelper.minSpeedKey(for: 0), "F0Mn")
        XCTAssertEqual(SMCKeyHelper.maxSpeedKey(for: 0), "F0Mx")
        XCTAssertEqual(SMCKeyHelper.fanModeKey(for: 0), "F0Md")
    }

    func testFanNaming() {
        XCTAssertEqual(SMCKeyHelper.defaultFanName(for: 0, totalFans: 1), "Main Fan")
        XCTAssertEqual(SMCKeyHelper.defaultFanName(for: 0, totalFans: 2), "Left Fan")
        XCTAssertEqual(SMCKeyHelper.defaultFanName(for: 1, totalFans: 2), "Right Fan")
        XCTAssertEqual(SMCKeyHelper.defaultFanName(for: 2, totalFans: 3), "Fan 2")
    }

    func testCategorizeKeys() {
        let cpuProximity = SMCKeyHelper.categorizeKey("TC0P")
        XCTAssertEqual(cpuProximity?.category, .cpu)

        let gpuProximity = SMCKeyHelper.categorizeKey("TG0P")
        XCTAssertEqual(gpuProximity?.category, .gpu)

        let battery = SMCKeyHelper.categorizeKey("TB0T")
        XCTAssertEqual(battery?.category, .battery)

        let palm = SMCKeyHelper.categorizeKey("TaLP")
        XCTAssertEqual(palm?.category, .ambient)

        // Apple Silicon dynamic keys
        let pCore = SMCKeyHelper.categorizeKey("Tp01")
        XCTAssertEqual(pCore?.category, .cpu)

        let eCore = SMCKeyHelper.categorizeKey("Te04")
        XCTAssertEqual(eCore?.category, .cpu)

        let gpuCluster = SMCKeyHelper.categorizeKey("Tg05")
        XCTAssertEqual(gpuCluster?.category, .gpu)
    }

    func testFanPercentageCalculation() {
        let fan = Fan(
            id: 0,
            name: "Left Fan",
            currentRPM: 4000,
            targetRPM: 4000,
            minRPM: 2000,
            maxRPM: 6000,
            mode: .auto
        )

        XCTAssertEqual(fan.percentage, 50.0, accuracy: 0.01)
        XCTAssertEqual(fan.targetPercentage, 50.0, accuracy: 0.01)
    }

    func testThermalStateCalculations() {
        let sensors = [
            ThermalSensor(id: "1", name: "CPU Core 1", category: .cpu, temperatureCelsius: 50.0),
            ThermalSensor(id: "2", name: "CPU Core 2", category: .cpu, temperatureCelsius: 60.0),
            ThermalSensor(id: "3", name: "GPU 1", category: .gpu, temperatureCelsius: 45.0),
            ThermalSensor(id: "4", name: "Battery", category: .battery, temperatureCelsius: 32.0),
            ThermalSensor(id: "5", name: "Ambient", category: .ambient, temperatureCelsius: 28.0)
        ]

        let state = ThermalState(fans: [], sensors: sensors)

        XCTAssertEqual(state.cpuAverageTemp, 55.0)
        XCTAssertEqual(state.cpuMaxTemp, 60.0)
        XCTAssertEqual(state.gpuAverageTemp, 45.0)
        XCTAssertEqual(state.gpuMaxTemp, 45.0)
        XCTAssertEqual(state.batteryTemp, 32.0)
        XCTAssertEqual(state.ambientTemp, 28.0)
    }
}
