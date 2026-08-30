//
//  AppDelegate.swift
//  MediStock
//
//  Created by Vincent Saluzzo on 28/05/2024.
//  Modified by Mathieu Arrio on 2026/08/30.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    // Skip Firebase setup when the app is only hosting a unit-test bundle, so tests
    // never initialize or reach the production Firebase project.
    guard NSClassFromString("XCTestCase") == nil else { return true }

    FirebaseApp.configure()

    // UI tests launch the app with `-useFirebaseEmulator`, which routes every Auth and
    // Firestore call to the local Emulator Suite instead of the production project.
    // Wiring happens here, before any repository or `SessionStore` touches Firebase.
    if ProcessInfo.processInfo.arguments.contains("-useFirebaseEmulator") {
      connectToFirebaseEmulator()
    }

    return true
  }

  /// Points Auth and Firestore at the local Emulator Suite (see `firebase.json`).
  /// Storage is intentionally left alone — the app never uses it.
  private func connectToFirebaseEmulator() {
    let host = "127.0.0.1"

    Auth.auth().useEmulator(withHost: host, port: 9099)

    let settings = Firestore.firestore().settings
    settings.host = "\(host):8080"
    settings.isSSLEnabled = false
    // No on-disk cache, so each test run starts from the emulator's current state
    // rather than a stale local snapshot.
    settings.cacheSettings = MemoryCacheSettings()
    Firestore.firestore().settings = settings

    // Firebase Auth persists the signed-in user in the keychain, which survives app
    // reinstalls on the simulator. `-signOutOnLaunch` clears it so a UI test can start
    // from the login screen; without it a relaunch keeps the session (used to get a
    // signed-in app in a fresh process).
    if ProcessInfo.processInfo.arguments.contains("-signOutOnLaunch") {
      try? Auth.auth().signOut()
    }
  }
}
