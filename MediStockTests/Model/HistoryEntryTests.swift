//
//  HistoryEntryTests.swift
//  MediStockTests
//
//  Created by Mathieu Arrio on 2026/08/30.
//

import XCTest
@testable import MediStock

final class HistoryEntryTests: XCTestCase {

    func testInitDefaultsIdToNilAndTimestampToNow() {
        let before = Date()
        let entry = HistoryEntry(medicineId: "m1", user: "u@example.com", action: "Added", details: "Added new medicine")
        let after = Date()

        XCTAssertNil(entry.id)
        XCTAssertGreaterThanOrEqual(entry.timestamp, before)
        XCTAssertLessThanOrEqual(entry.timestamp, after)
    }

    func testInitStoresEveryProvidedValue() {
        let timestamp = Date(timeIntervalSince1970: 1_000_000)
        let entry = HistoryEntry(
            id: "h1",
            medicineId: "m1",
            user: "u@example.com",
            action: "Updated Doliprane",
            details: "Stock changed from 5 to 8",
            timestamp: timestamp
        )

        XCTAssertEqual(entry.id, "h1")
        XCTAssertEqual(entry.medicineId, "m1")
        XCTAssertEqual(entry.user, "u@example.com")
        XCTAssertEqual(entry.action, "Updated Doliprane")
        XCTAssertEqual(entry.details, "Stock changed from 5 to 8")
        XCTAssertEqual(entry.timestamp, timestamp)
    }
}
