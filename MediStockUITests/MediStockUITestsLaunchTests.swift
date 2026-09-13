//
//  MediStockUITestsLaunchTests.swift
//  MediStockUITests
//
//  Created by Vincent Saluzzo on 28/05/2024.
//  Modified by Mathieu Arrio on 2026/08/30.
//

import XCTest

final class MediStockUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunch() throws {
        let app = XCUIApplication()
        // Point at the Emulator Suite so a screenshot run never touches production.
        app.launchArguments += ["-useFirebaseEmulator"]
        app.launch()

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
