//
//  MockAuthService.swift
//  MediStockTests
//
//  Created by Mathieu Arrio on 2026/08/30.
//

import Foundation
@testable import MediStock

/// In-memory `AuthServicing` for unit tests. Captures the state listener so a test
/// can drive `session` via `emitUser`, records every call, and can be told to throw.
@MainActor
final class MockAuthService: AuthServicing {

    private(set) var stateListener: ((User?) -> Void)?
    private(set) var addStateListenerCallCount = 0
    private(set) var cancelledTokenCount = 0

    private(set) var signInCalls: [(email: String, password: String)] = []
    private(set) var signUpCalls: [(email: String, password: String)] = []
    private(set) var signOutCalled = false

    var errorToThrow: Error?
    var signOutError: Error?
    var stubUser = User(uid: "test-uid", email: "user@example.com")

    func addStateListener(_ onChange: @escaping (User?) -> Void) -> ListenerToken {
        addStateListenerCallCount += 1
        stateListener = onChange
        return ClosureListenerToken { [weak self] in self?.cancelledTokenCount += 1 }
    }

    func signIn(email: String, password: String) async throws -> User {
        signInCalls.append((email, password))
        if let errorToThrow { throw errorToThrow }
        return stubUser
    }

    func signUp(email: String, password: String) async throws -> User {
        signUpCalls.append((email, password))
        if let errorToThrow { throw errorToThrow }
        return stubUser
    }

    func signOut() throws {
        signOutCalled = true
        if let signOutError { throw signOutError }
    }

    // MARK: Test helpers

    func emitUser(_ user: User?) {
        stateListener?(user)
    }
}
