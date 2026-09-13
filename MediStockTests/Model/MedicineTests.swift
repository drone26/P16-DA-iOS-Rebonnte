//
//  MedicineTests.swift
//  MediStockTests
//
//  Created by Mathieu Arrio on 2026/08/30.
//

import XCTest
@testable import MediStock

final class MedicineTests: XCTestCase {

    // MARK: - Equatable / Hashable

    func testEqualityMatchesOnEverySignificantField() {
        let a = Medicine(id: "1", name: "abc", stock: 1, aisle: "A")
        let b = Medicine(id: "1", name: "abc", stock: 1, aisle: "A")
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testInequalityOnEachSignificantField() {
        let base = Medicine(id: "1", name: "abc", stock: 1, aisle: "A")
        XCTAssertNotEqual(base, Medicine(id: "2", name: "abc", stock: 1, aisle: "A"))
        XCTAssertNotEqual(base, Medicine(id: "1", name: "xyz", stock: 1, aisle: "A"))
        XCTAssertNotEqual(base, Medicine(id: "1", name: "abc", stock: 9, aisle: "A"))
        XCTAssertNotEqual(base, Medicine(id: "1", name: "abc", stock: 1, aisle: "B"))
    }

    // MARK: - changeDescription

    func testChangeDescriptionForNameOnly() {
        let previous = Medicine(id: "1", name: "Doliprane", stock: 5, aisle: "A")
        let updated = Medicine(id: "1", name: "Dolipranum", stock: 5, aisle: "A")
        XCTAssertEqual(
            Medicine.changeDescription(from: previous, to: updated),
            "Name changed from \"Doliprane\" to \"Dolipranum\""
        )
    }

    func testChangeDescriptionForStockOnly() {
        let previous = Medicine(id: "1", name: "Doliprane", stock: 5, aisle: "A")
        let updated = Medicine(id: "1", name: "Doliprane", stock: 8, aisle: "A")
        XCTAssertEqual(
            Medicine.changeDescription(from: previous, to: updated),
            "Stock changed from 5 to 8"
        )
    }

    func testChangeDescriptionForAisleOnly() {
        let previous = Medicine(id: "1", name: "Doliprane", stock: 5, aisle: "A")
        let updated = Medicine(id: "1", name: "Doliprane", stock: 5, aisle: "B")
        XCTAssertEqual(
            Medicine.changeDescription(from: previous, to: updated),
            "Aisle changed from \"A\" to \"B\""
        )
    }

    func testChangeDescriptionForMultipleFields() {
        let previous = Medicine(id: "1", name: "Doliprane", stock: 5, aisle: "A")
        let updated = Medicine(id: "1", name: "Aspirin", stock: 2, aisle: "C")
        XCTAssertEqual(
            Medicine.changeDescription(from: previous, to: updated),
            "Name changed from \"Doliprane\" to \"Aspirin\"; Stock changed from 5 to 2; Aisle changed from \"A\" to \"C\""
        )
    }

    func testChangeDescriptionForNoChange() {
        let medicine = Medicine(id: "1", name: "Doliprane", stock: 5, aisle: "A")
        XCTAssertEqual(Medicine.changeDescription(from: medicine, to: medicine), "No changes")
    }
}
