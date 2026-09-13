//
//  AuthServicing.swift
//  MediStock
//
//  Created by Mathieu Arrio on 2026/08/30.
//

import Foundation

/// The authentication operations `SessionStore` needs, expressed in terms of the
/// app's own `User` model. `FirebaseAuthService` is the production implementation;
/// tests inject an in-memory mock so no unit test ever authenticates against the
/// real Firebase project.
@MainActor
protocol AuthServicing {
    /// Registers a listener for auth-state changes, invoked with the current user
    /// (or `nil` when signed out). Delivered on the main actor.
    func addStateListener(_ onChange: @escaping (User?) -> Void) -> ListenerToken

    func signIn(email: String, password: String) async throws -> User
    func signUp(email: String, password: String) async throws -> User
    func signOut() throws
}
