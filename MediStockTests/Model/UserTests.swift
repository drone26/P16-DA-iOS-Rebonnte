//
//  UserTests.swift
//  MediStockTests
//
//  Created by Mathieu Arrio on 2026/08/30.
//

import XCTest
@testable import MediStock

final class UserTests: XCTestCase {

    func testIdentifierUsesEmailWhenPresent() {
        let user = User(uid: "abc123", email: "user@example.com")
        XCTAssertEqual(user.identifier, "user@example.com")
    }

    func testIdentifierFallsBackToUidWhenEmailIsNil() {
        let user = User(uid: "abc123", email: nil)
        XCTAssertEqual(user.identifier, "abc123")
    }
}
