//
//  MediStockApp.swift
//  MediStock
//
//  Created by Vincent Saluzzo on 28/05/2024.
//  Modified by Mathieu Arrio on 2026/08/18.
//

import SwiftUI

@main
struct MediStockApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var sessionStore = SessionStore()

    /// True when the process is only hosting a unit-test bundle. In that case the
    /// real UI (which listens to Firebase Auth on appear) is never built, so tests
    /// stay fully isolated from the production Firebase project.
    private var isRunningUnitTests: Bool {
        NSClassFromString("XCTestCase") != nil
    }

    var body: some Scene {
        WindowGroup {
            if isRunningUnitTests {
                Color.clear
            } else {
                ContentView()
                    .environment(sessionStore)
            }
        }
    }
}
