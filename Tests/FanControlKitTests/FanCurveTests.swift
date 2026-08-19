import XCTest
@testable import FanControlKit

final class FanCurveTests: XCTestCase {
    func testLinearInterpolation() {
        let fan = Fan(
            id: 0,
            name: "Main Fan",
            currentRPM: 2000,
            targetRPM: 2000,
            minRPM: 2000,
            maxRPM: 6000,
            mode: .auto
        )

        let config = FanCurveConfig(
            fanId: 0,
            sensorCategory: .cpu,
            minTemp: 40.0,
            maxTemp: 80.0,
            minRPM: 2000,
            maxRPM: 6000
        )

        let controller = FanCurveController(config: config)

        // Below min temp -> min RPM
        XCTAssertEqual(controller.calculateTargetRPM(currentTemp: 35.0, fan: fan), 2000.0)

        // Above max temp -> max RPM
        XCTAssertEqual(controller.calculateTargetRPM(currentTemp: 90.0, fan: fan), 6000.0)

        // At min temp -> min RPM
        XCTAssertEqual(controller.calculateTargetRPM(currentTemp: 40.0, fan: fan), 2000.0)

        // At max temp -> max RPM
        XCTAssertEqual(controller.calculateTargetRPM(currentTemp: 80.0, fan: fan), 6000.0)

        // Exactly halfway (60°C) -> 4000 RPM
        XCTAssertEqual(controller.calculateTargetRPM(currentTemp: 60.0, fan: fan), 4000.0)

        // At 25% (50°C) -> 3000 RPM
        XCTAssertEqual(controller.calculateTargetRPM(currentTemp: 50.0, fan: fan), 3000.0)
    }
}
