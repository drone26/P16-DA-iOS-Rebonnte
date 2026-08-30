//
//  AppDelegate.swift
//  MediStock
//
//  Created by Vincent Saluzzo on 28/05/2024.
//  Modified by Mathieu Arrio on 2026/08/05.
//

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    // Skip Firebase setup when the app is only hosting a unit-test bundle, so tests
    // never initialize or reach the production Firebase project.
    if NSClassFromString("XCTestCase") == nil {
      FirebaseApp.configure()
    }
    return true
  }
}
