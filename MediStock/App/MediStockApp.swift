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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(sessionStore)
        }
    }
}
