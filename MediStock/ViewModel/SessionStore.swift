//
//  SessionStore.swift
//  MediStock
//
//  Created by Mathieu Arrio on 2026/08/18.
//

import Foundation
import Observation

@Observable
@MainActor
final class SessionStore {
    var session: User?
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

    /// Mirrors Firebase Auth's own minimum password length so the app can reject a too-short
    /// password locally instead of round-tripping to the server for the same rejection.
    func isValidPassword(_ password: String) -> Bool {
        password.count >= 20
    }

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

    func unbind() {
        stateListener?.cancel()
        stateListener = nil
    }

    deinit {
        stateListener?.cancel()
    }
}
