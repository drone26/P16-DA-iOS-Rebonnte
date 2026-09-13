//
//  SortOptionTests.swift
//  MediStockTests
//
//  Created by Mathieu Arrio on 2026/08/30.
//

import XCTest
@testable import MediStock

final class SortOptionTests: XCTestCase {

    func testAllCasesInDeclaredOrder() {
        XCTAssertEqual(SortOption.allCases, [.none, .name, .stock])
    }

    func testIdMatchesRawValue() {
        for option in SortOption.allCases {
            XCTAssertEqual(option.id, option.rawValue)
        }
    }
}
