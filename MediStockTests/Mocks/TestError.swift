//
//  TestError.swift
//  MediStockTests
//
//  Created by Mathieu Arrio on 2026/08/30.
//

import Foundation

/// Generic error used by the mocks to exercise the ViewModels' `catch` paths.
enum TestError: LocalizedError {
    case boom

    var errorDescription: String? { "Something went wrong (test)." }
}
