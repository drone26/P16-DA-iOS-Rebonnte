//
//  SessionStore.swift
//  MediStock
//
//  Created by Mathieu Arrio on 2026/08/18.
//

import Foundation
import Observation
import Firebase

@Observable
@MainActor
final class SessionStore {
    var session: User?
    var errorMessage: String?
    @ObservationIgnored
    private nonisolated(unsafe) var handle: AuthStateDidChangeListenerHandle?

    func listen() {
        guard handle == nil else { return }
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            if let user {
                self.session = User(uid: user.uid, email: user.email)
            } else {
                self.session = nil
            }
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
        password.count >= 6
    }

    func signUp(email: String, password: String) {
        guard isValidEmail(email) else {
            errorMessage = "Please enter a valid email address."
            return
        }
        guard isValidPassword(password) else {
            errorMessage = "Password must be at least 20 characters."
            return
        }
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            Task { @MainActor in
                if let error {
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.session = User(uid: result?.user.uid ?? "", email: result?.user.email ?? "")
                }
            }
        }
    }

    func signIn(email: String, password: String) {
        guard isValidEmail(email) else {
            errorMessage = "Please enter a valid email address."
            return
        }
        guard isValidPassword(password) else {
            errorMessage = "Password must be at least 6 characters."
            return
        }
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            Task { @MainActor in
                if let error {
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.session = User(uid: result?.user.uid ?? "", email: result?.user.email ?? "")
                }
            }
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            session = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func unbind() {
        if let handle {
            Auth.auth().removeStateDidChangeListener(handle)
            self.handle = nil
        }
    }

    deinit {
        if let handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}
