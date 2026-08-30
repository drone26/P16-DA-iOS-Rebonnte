//
//  LoginUITests.swift
//  MediStockUITests
//
//  Created by Mathieu Arrio on 2026/08/30.
//

import XCTest

/// Drives the login screen against the Auth emulator.
final class LoginUITests: EmulatorUITestCase {

    func testLoginScreenIsShownWhenSignedOut() {
        app.launch()

        XCTAssertTrue(app.textFields["Email"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.secureTextFields["Password"].exists)
        XCTAssertTrue(app.buttons["Login"].exists)
        XCTAssertTrue(app.buttons["Sign Up"].exists)
    }

    func testInvalidEmailAndShortPasswordDisableSubmit() {
        app.launch()

        let emailField = app.textFields["Email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 15))
        emailField.tap()
        emailField.typeText("not-an-email")

        XCTAssertTrue(app.staticTexts["Enter a valid email address"].waitForExistence(timeout: 5))

        let passwordField = app.secureTextFields["Password"]
        passwordField.tap()
        passwordField.typeText("short")

        XCTAssertTrue(app.staticTexts["Password must be at least 20 characters"].exists)
        XCTAssertFalse(app.buttons["Login"].isEnabled)
        XCTAssertFalse(app.buttons["Sign Up"].isEnabled)
    }

    func testSignUpCreatesAccountAndEntersApp() {
        let email = "signup-\(UUID().uuidString.prefix(8))@medistock.test"
        app.launch()

        let emailField = app.textFields["Email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 15))
        emailField.tap()
        emailField.typeText(email)

        let passwordField = app.secureTextFields["Password"]
        passwordField.tap()
        passwordField.typeText(validPassword)

        app.buttons["Sign Up"].tap()

        XCTAssertTrue(app.tabBars.buttons["Aisles"].waitForExistence(timeout: 20))
    }

    func testSignInWithSeededAccountEntersApp() {
        launchAndSignIn(email: "seeded-user@medistock.test")

        XCTAssertTrue(app.tabBars.buttons["All Medicines"].exists)
        XCTAssertTrue(app.tabBars.buttons["Profile"].exists)
    }

    func testSignInWithWrongPasswordShowsError() {
        FirebaseEmulator.createUser(email: "wrong-pw@medistock.test", password: validPassword)
        app.launch()

        let emailField = app.textFields["Email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 15))
        emailField.tap()
        emailField.typeText("wrong-pw@medistock.test")

        let passwordField = app.secureTextFields["Password"]
        passwordField.tap()
        passwordField.typeText(String(repeating: "b", count: 20))

        app.buttons["Login"].tap()

        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 10), "Expected an auth error alert")
        XCTAssertFalse(app.tabBars.buttons["Aisles"].exists)
    }
}
