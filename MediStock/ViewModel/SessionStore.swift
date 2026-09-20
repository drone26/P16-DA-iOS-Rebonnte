//
//  SessionStore.swift
//  MediStock
//
//  Created by Mathieu Arrio on 2026/08/18.
//

import Foundation
import Observation

/// Owns the authentication state for the whole app: who is signed in, and the
/// sign-in / sign-up / sign-out actions. Injected into the view hierarchy through the
/// environment; `AuthServicing` keeps it decoupled from Firebase so tests can mock it.
@Observable
@MainActor
final class SessionStore {
    /// The signed-in user, or `nil` when signed out. Drives which root screen is shown.
    var session: User?
    /// Message for the login screen's error alert; set on validation or auth failure.
    var errorMessage: String?

    @ObservationIgnored
    private let auth: AuthServicing
    @ObservationIgnored
    private nonisolated(unsafe) var stateListener: ListenerToken?

    convenience init() {
        self.init(auth: FirebaseAuthService())
    }

    init(auth: AuthServicing) {
        self.auth = auth
    }

    /// Starts observing auth state so `session` follows sign-ins, sign-outs and a session
    /// restored from a previous launch. Safe to call more than once.
    func listen() {
        guard stateListener == nil else { return }
        stateListener = auth.addStateListener { [weak self] user in
            self?.session = user
        }
    }

    /// Basic email shape check (`local@domain.tld`), just enough to catch typos before
    /// spending a network round-trip on Firebase rejecting it.
    func isValidEmail(_ email: String) -> Bool {
        let regex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: regex, options: .regularExpression) != nil
    }

    /// The app's own password policy: at least 20 characters. It is enforced here, before
    /// any network call, independently of any policy configured in Firebase Auth.
    func isValidPassword(_ password: String) -> Bool {
        password.count >= 20
    }

    /// Creates an account and signs it in. Invalid input is rejected locally; any failure
    /// from the auth service ends up in `errorMessage`.
    func signUp(email: String, password: String) async {
        guard isValidEmail(email) else {
            errorMessage = "Please enter a valid email address."
            return
        }
        guard isValidPassword(password) else {
            errorMessage = "Password must be at least 20 characters."
            return
        }
        do {
            session = try await auth.signUp(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Signs in an existing account, with the same local validation and error reporting
    /// as `signUp`.
    func signIn(email: String, password: String) async {
        guard isValidEmail(email) else {
            errorMessage = "Please enter a valid email address."
            return
        }
        guard isValidPassword(password) else {
            errorMessage = "Password must be at least 20 characters."
            return
        }
        do {
            session = try await auth.signIn(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        do {
            try auth.signOut()
            session = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Stops observing auth state; a later `listen()` starts it again.
    func unbind() {
        stateListener?.cancel()
        stateListener = nil
    }

    deinit {
        stateListener?.cancel()
    }
}
