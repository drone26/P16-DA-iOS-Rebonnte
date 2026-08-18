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

    func signUp(email: String, password: String) {
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
