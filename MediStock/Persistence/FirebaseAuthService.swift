//
//  FirebaseAuthService.swift
//  MediStock
//
//  Created by Mathieu Arrio on 2026/08/30.
//

import Foundation
import Firebase

/// Production `AuthServicing` backed by Firebase Auth. The only place in the app
/// that references `Auth` — `SessionStore` talks to the protocol so it can be
/// tested against an in-memory mock.
@MainActor
final class FirebaseAuthService: AuthServicing {
    enum AuthError: LocalizedError {
        case missingUser

        var errorDescription: String? {
            switch self {
            case .missingUser:
                return "Authentication succeeded but no user was returned."
            }
        }
    }

    func addStateListener(_ onChange: @escaping (User?) -> Void) -> ListenerToken {
        let handle = Auth.auth().addStateDidChangeListener { _, user in
            Task { @MainActor in
                onChange(user.map { User(uid: $0.uid, email: $0.email) })
            }
        }
        return ClosureListenerToken {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    func signIn(email: String, password: String) async throws -> User {
        try await withCheckedThrowingContinuation { continuation in
            Auth.auth().signIn(withEmail: email, password: password) { result, error in
                Self.resume(continuation, result: result, error: error)
            }
        }
    }

    func signUp(email: String, password: String) async throws -> User {
        try await withCheckedThrowingContinuation { continuation in
            Auth.auth().createUser(withEmail: email, password: password) { result, error in
                Self.resume(continuation, result: result, error: error)
            }
        }
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    private nonisolated static func resume(
        _ continuation: CheckedContinuation<User, Error>,
        result: AuthDataResult?,
        error: Error?
    ) {
        if let error {
            continuation.resume(throwing: error)
        } else if let user = result?.user {
            continuation.resume(returning: User(uid: user.uid, email: user.email))
        } else {
            continuation.resume(throwing: AuthError.missingUser)
        }
    }
}
