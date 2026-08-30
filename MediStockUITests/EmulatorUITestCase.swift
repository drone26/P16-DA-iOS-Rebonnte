//
//  EmulatorUITestCase.swift
//  MediStockUITests
//
//  Created by Mathieu Arrio on 2026/08/30.
//

import XCTest

/// Base class for UI tests that exercise the real app against the Firebase Emulator
/// Suite. Each test gets a fresh emulator state and an `XCUIApplication` already
/// configured to talk to the emulators; it just calls `app.launch()`.
class EmulatorUITestCase: XCTestCase {

    let app = XCUIApplication()

    /// A password that clears the app's 20-character minimum.
    let validPassword = String(repeating: "a", count: 20)

    override func setUpWithError() throws {
        continueAfterFailure = false

        try XCTSkipUnless(
            FirebaseEmulator.isRunning,
            "Firebase Emulator Suite is not running. Start it with `firebase emulators:start`."
        )

        // The launch-screenshot tests leave the simulator rotated; these flows assume
        // portrait (the tab bar and toolbar buttons aren't reliably hittable in
        // landscape on iPhone).
        XCUIDevice.shared.orientation = .portrait

        FirebaseEmulator.reset()
        // `-signOutOnLaunch` makes the app start from the login screen; `launchAndSignIn`
        // drops it before relaunching to get a signed-in app in a clean process.
        app.launchArguments += ["-useFirebaseEmulator", "-signOutOnLaunch"]
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    // MARK: - Shared flows

    /// Creates an account in the Auth emulator, launches the app, and signs in through
    /// the login screen. Leaves the app on `MainTabView`.
    func launchAndSignIn(
        email: String = "uitester@medistock.test",
        password: String? = nil
    ) {
        let password = password ?? validPassword
        FirebaseEmulator.createUser(email: email, password: password)

        app.launch()

        let emailField = app.textFields["Email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 15), "Login screen never appeared")
        emailField.tap()
        emailField.typeText(email)

        let passwordField = app.secureTextFields["Password"]
        passwordField.tap()
        passwordField.typeText(password)

        // iOS's "Save Password?" / AutoFill sheet is presented by SpringBoard and can pop
        // up over the Login button, swallowing the tap so sign-in never fires and the tab
        // bar never appears. Retry the tap, dismissing the sheet each pass, until the tabs
        // show up or we run out of time.
        let aislesTab = app.tabBars.buttons["Aisles"]
        let loginButton = app.buttons["Login"]
        let signInDeadline = Date().addingTimeInterval(30)
        repeat {
            if loginButton.exists && loginButton.isHittable {
                loginButton.tap()
            }
            dismissSavePasswordPromptIfPresent()
        } while !aislesTab.waitForExistence(timeout: 3) && Date() < signInDeadline

        XCTAssertTrue(
            aislesTab.exists,
            "Did not reach the main tab view after signing in"
        )

        // The "Save Password?" sheet leaves an invisible window that keeps swallowing
        // touches to the tab bar. Relaunch in a clean process — Firebase restores the
        // now-persisted session (no `-signOutOnLaunch`), landing straight on the tabs.
        app.launchArguments.removeAll { $0 == "-signOutOnLaunch" }
        app.launch()

        XCTAssertTrue(
            app.tabBars.buttons["Aisles"].waitForExistence(timeout: 20),
            "Session was not restored after relaunch"
        )
    }

    /// After a password sign-in iOS puts up a "Save Password?" system sheet that
    /// intercepts every touch until it's dismissed. It's presented by SpringBoard, so its
    /// buttons live in that process — not `app` — which is why we query SpringBoard here.
    /// Taps the decline button, matched across the English and French simulator locales.
    @discardableResult
    func dismissSavePasswordPromptIfPresent() -> Bool {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let declineLabels = ["Not Now", "Not now", "Pas maintenant", "Plus tard"]
        for host in [springboard, app] {
            for label in declineLabels {
                let button = host.buttons[label]
                if button.exists {
                    button.tap()
                    return true
                }
            }
        }
        return false
    }

    /// Polls `condition` until it's true or `timeout` elapses.
    @discardableResult
    func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return condition()
    }

    /// Switches to a tab. A coordinate tap is the fallback because SwiftUI's `TabView`
    /// tab items occasionally report `isHittable == false` even with a valid frame.
    func tapTab(_ label: String) {
        let tab = app.tabBars.buttons[label]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "\(label) tab not found")
        waitUntil(timeout: 5) { tab.isHittable }
        if tab.isHittable {
            tab.tap()
        } else {
            tab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    /// Opens the "All Medicines" tab and adds a medicine through the "+" form.
    func addMedicine(name: String, stock: Int, aisle: String) {
        tapTab("All Medicines")

        let addButton = app.buttons["Add medicine"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 10), "Add-medicine button never appeared")
        addButton.tap()

        let nameField = app.textFields["Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Add-medicine form never appeared")
        nameField.tap()
        nameField.typeText(name)

        let aisleField = app.textFields["Aisle"]
        aisleField.tap()
        aisleField.typeText(aisle)

        // Stock starts at 0; step it up rather than fighting the number-pad field.
        let increase = app.buttons["Increase stock"]
        for _ in 0..<stock { increase.tap() }

        // The save button sits below the fields and can be behind the keyboard;
        // scroll it up if it isn't tappable yet.
        let save = app.buttons["Add Medicine"]
        if !save.isHittable {
            app.swipeUp()
        }
        save.tap()
    }

    /// The medicine list row for `name`, keyed by the accessibility identifier
    /// `MedicineRow` sets. `.any` because a `NavigationLink` row surfaces as a button
    /// on some OS versions and a cell on others.
    func medicineRow(named name: String) -> XCUIElement {
        app.descendants(matching: .any)["medicineRow-\(name)"].firstMatch
    }
}
