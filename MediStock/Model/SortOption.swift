//
//  SortOption.swift
//  MediStock
//
//  Created by Mathieu Arrio on 2026/08/18.
//

import Foundation

/// How the "All Medicines" list is ordered. Applied server-side by the repository,
/// not by sorting the loaded page on the client.
enum SortOption: String, CaseIterable, Identifiable {
    /// No explicit ordering (Firestore's default document order).
    case none
    case name
    case stock

    var id: String { self.rawValue }
}
