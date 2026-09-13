//
//  MedicineFlowUITests.swift
//  MediStockUITests
//
//  Created by Mathieu Arrio on 2026/08/30.
//

import XCTest

/// End-to-end medicine flows against the Auth + Firestore emulators: a signed-in user
/// adding, browsing, filtering and deleting medicines, then logging out.
final class MedicineFlowUITests: EmulatorUITestCase {

    func testAddedMedicineAppearsInAllMedicinesList() {
        launchAndSignIn()

        addMedicine(name: "Doliprane", stock: 12, aisle: "Aisle A")

        tapTab("All Medicines")
        XCTAssertTrue(medicineRow(named: "Doliprane").waitForExistence(timeout: 15))
    }

    func testAddedMedicineCreatesItsAisle() {
        launchAndSignIn()

        addMedicine(name: "Ibuprofen", stock: 5, aisle: "Aisle Z")

        tapTab("Aisles")
        XCTAssertTrue(app.staticTexts["Aisle Z"].waitForExistence(timeout: 15))

        app.staticTexts["Aisle Z"].tap()
        XCTAssertTrue(medicineRow(named: "Ibuprofen").waitForExistence(timeout: 15))
    }

    func testFilterMedicinesByName() {
        FirebaseEmulator.seedMedicine(name: "Doliprane", stock: 10, aisle: "Aisle A")
        FirebaseEmulator.seedMedicine(name: "Aspirin", stock: 8, aisle: "Aisle B")
        FirebaseEmulator.seedMedicine(name: "Amoxicillin", stock: 3, aisle: "Aisle B")

        launchAndSignIn()
        tapTab("All Medicines")

        XCTAssertTrue(medicineRow(named: "Doliprane").waitForExistence(timeout: 15))

        let filterField = app.textFields["Filter by name"]
        filterField.tap()
        filterField.typeText("Doli")

        XCTAssertTrue(medicineRow(named: "Doliprane").waitForExistence(timeout: 10))
        XCTAssertFalse(medicineRow(named: "Aspirin").exists)
        XCTAssertFalse(medicineRow(named: "Amoxicillin").exists)
    }

    func testDeleteMedicineRemovesItFromList() {
        FirebaseEmulator.seedMedicine(name: "Expired Syrup", stock: 1, aisle: "Aisle C")

        launchAndSignIn()
        tapTab("All Medicines")

        let row = medicineRow(named: "Expired Syrup")
        XCTAssertTrue(row.waitForExistence(timeout: 15))

        row.swipeLeft()
        // A full swipe can fire the delete action directly; otherwise tap the revealed
        // swipe-action button. Either way a confirmation alert follows.
        if !app.alerts.firstMatch.waitForExistence(timeout: 4) {
            app.buttons["Delete"].firstMatch.tap()
        }
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5), "Delete confirmation alert never appeared")
        app.alerts.buttons["Delete"].tap()

        XCTAssertTrue(medicineRow(named: "Expired Syrup").waitForNonExistence(timeout: 15))
    }

    func testEditMedicineStockPersists() {
        FirebaseEmulator.seedMedicine(name: "Paracetamol", stock: 4, aisle: "Aisle D")

        launchAndSignIn()
        tapTab("All Medicines")

        let row = medicineRow(named: "Paracetamol")
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        row.tap()

        XCTAssertTrue(app.buttons["Increase stock"].waitForExistence(timeout: 5))
        app.buttons["Increase stock"].tap()
        app.buttons["Save Changes"].tap()

        // Re-open from the list and confirm the new value stuck.
        app.navigationBars.buttons.firstMatch.tap()   // back
        let updated = medicineRow(named: "Paracetamol")
        XCTAssertTrue(updated.waitForExistence(timeout: 10))
        XCTAssertTrue(updated.label.contains("Stock: 5"))
    }

    func testLogoutReturnsToLoginScreen() {
        launchAndSignIn()

        tapTab("Profile")
        app.buttons["Logout"].tap()

        XCTAssertTrue(app.textFields["Email"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.tabBars.buttons["Aisles"].exists)
    }
}
