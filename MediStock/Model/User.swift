//
//  User.swift
//  MediStock
//
//  Created by Mathieu Arrio on 2026/08/07.
//

import Foundation

struct User {
    var uid: String
    var email: String?

    /// The most human-readable way to identify this user in places like the change
    /// history (email is far more useful than a raw Firebase UID). Falls back to the
    /// UID for the rare case a user has no email on file.
    var identifier: String {
        email ?? uid
    }
}
