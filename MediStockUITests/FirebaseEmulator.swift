//
//  FirebaseEmulator.swift
//  MediStockUITests
//
//  Created by Mathieu Arrio on 2026/08/30.
//

import Foundation
import XCTest

/// Talks to the local Firebase Emulator Suite over its REST admin endpoints so UI
/// tests can start from a known state. The app under test is launched with
/// `-useFirebaseEmulator` (see `AppDelegate`), so every read/write it performs goes
/// to these same emulators — never the production project.
enum FirebaseEmulator {

    /// Must match `PROJECT_ID` in `GoogleService-Info.plist`: the emulators key all
    /// state by project id.
    static let projectID = "gestionstockmedicaments-3818"
    static let host = "127.0.0.1"
    static let authPort = 9099
    static let firestorePort = 8080

    private static var authBase: String { "http://\(host):\(authPort)" }
    private static var firestoreBase: String { "http://\(host):\(firestorePort)" }

    // MARK: - Availability

    /// True when both the Auth and Firestore emulators answer. Tests skip (rather than
    /// fail) when the suite isn't running.
    static var isRunning: Bool {
        status(url: "\(authBase)/") != nil && status(url: "\(firestoreBase)/") != nil
    }

    // MARK: - Reset

    /// Wipes every Auth account and every Firestore document so each test is isolated.
    static func reset(file: StaticString = #filePath, line: UInt = #line) {
        send(
            request("\(authBase)/emulator/v1/projects/\(projectID)/accounts", method: "DELETE"),
            file: file, line: line
        )
        send(
            request(
                "\(firestoreBase)/emulator/v1/projects/\(projectID)/databases/(default)/documents",
                method: "DELETE"
            ),
            file: file, line: line
        )
    }

    // MARK: - Seeding

    /// Creates an email/password account directly in the Auth emulator, so a test can
    /// exercise sign-in without first walking through sign-up.
    static func createUser(
        email: String,
        password: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        // The emulator accepts any API key.
        var req = request(
            "\(authBase)/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key",
            method: "POST"
        )
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "email": email,
            "password": password,
            "returnSecureToken": true
        ])
        send(req, file: file, line: line)
    }

    /// Inserts one medicine document straight into the Firestore emulator, including
    /// the precomputed lowercase `nameSubstrings` the app's name filter queries against.
    @discardableResult
    static func seedMedicine(
        id: String = UUID().uuidString,
        name: String,
        stock: Int,
        aisle: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> String {
        var req = request(
            "\(firestoreBase)/v1/projects/\(projectID)/databases/(default)/documents/medicines?documentId=\(id)",
            method: "POST"
        )
        let fields: [String: Any] = [
            "name": ["stringValue": name],
            "stock": ["integerValue": String(stock)],
            "aisle": ["stringValue": aisle],
            "nameSubstrings": ["arrayValue": ["values": substrings(of: name).map { ["stringValue": $0] }]]
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["fields": fields])
        send(req, file: file, line: line)
        return id
    }

    /// Mirrors `Medicine.substrings(of:)` in the app target (not importable here).
    private static func substrings(of name: String) -> [String] {
        let characters = Array(name.lowercased())
        guard !characters.isEmpty else { return [] }
        var result = Set<String>()
        for start in 0..<characters.count {
            for end in (start + 1)...characters.count {
                result.insert(String(characters[start..<end]))
            }
        }
        return Array(result)
    }

    // MARK: - Networking

    private static func request(_ urlString: String, method: String) -> URLRequest {
        var req = URLRequest(url: URL(string: urlString)!)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // The emulators accept a fake owner token for privileged admin routes.
        req.setValue("Bearer owner", forHTTPHeaderField: "Authorization")
        return req
    }

    /// Sends `req` synchronously and fails the current test if it errors or returns a
    /// non-2xx status.
    private static func send(_ req: URLRequest, file: StaticString, line: UInt) {
        let semaphore = DispatchSemaphore(value: 0)
        var failure: String?
        let task = URLSession.shared.dataTask(with: req) { data, response, error in
            defer { semaphore.signal() }
            if let error {
                failure = "\(req.httpMethod ?? "?") \(req.url?.absoluteString ?? "?") failed: \(error.localizedDescription)"
                return
            }
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            if !(200...299).contains(code) {
                let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                failure = "\(req.httpMethod ?? "?") \(req.url?.absoluteString ?? "?") → HTTP \(code): \(body)"
            }
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 15)
        if let failure {
            XCTFail(failure, file: file, line: line)
        }
    }

    /// Returns the HTTP status for a bare GET, or `nil` if the host is unreachable.
    private static func status(url: String) -> Int? {
        let semaphore = DispatchSemaphore(value: 0)
        var code: Int?
        let task = URLSession.shared.dataTask(with: URL(string: url)!) { _, response, _ in
            code = (response as? HTTPURLResponse)?.statusCode
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 5)
        return code
    }
}
