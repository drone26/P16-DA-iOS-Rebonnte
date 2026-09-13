//
//  MediStockUITests.swift
//  MediStockUITests
//
//  Created by Vincent Saluzzo on 28/05/2024.
//  Modified by Mathieu Arrio on 2026/08/30.
//

import XCTest

/// Smoke test: the app launches against the Firebase Emulator Suite and shows the
/// signed-out login screen. Feature flows live in `LoginUITests` and
/// `MedicineFlowUITests`.
final class MediStockUITests: EmulatorUITestCase {

    func testAppLaunchesToLoginScreen() throws {
        app.launch()

        XCTAssertTrue(app.textFields["Email"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["Login"].exists)
    }

    func testLaunchPerformance() throws {
        // A fresh app per iteration, still pointed at the emulator so the measurement
        // never contacts the production project.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let launchApp = XCUIApplication()
            launchApp.launchArguments += ["-useFirebaseEmulator"]
            launchApp.launch()
        }
    }
}
