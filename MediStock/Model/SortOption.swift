//
//  SortOption.swift
//  MediStock
//
//  Created by Mathieu Arrio on 2026/08/18.
//

import Foundation

enum SortOption: String, CaseIterable, Identifiable {
    case none
    case name
    case stock

    var id: String { self.rawValue }
}
