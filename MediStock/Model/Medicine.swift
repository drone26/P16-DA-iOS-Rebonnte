//
//  Medicine.swift
//  MediStock
//
//  Created by Vincent Saluzzo on 28/05/2024.
//  Modified by Mathieu Arrio on 2026/08/18.
//

import Foundation
import FirebaseFirestoreSwift

/// A medicine tracked in the `medicines` Firestore collection.
struct Medicine: Identifiable, Codable, Equatable, Hashable {
    /// The Firestore document ID; `nil` until the medicine has been saved.
    @DocumentID var id: String?
    var name: String
    /// Units in stock; must not be negative (see `MedicineStockViewModel.isValidStock`).
    var stock: Int
    var aisle: String

    init(id: String? = nil, name: String, stock: Int, aisle: String) {
        self.id = id
        self.name = name
        self.stock = stock
        self.aisle = aisle
    }

    /// Human-readable, field-by-field description of what changed between two revisions
    /// of the same medicine, e.g. `Name changed from "Doliprane" to "Dolipranum"`. Used
    /// to give each edit's history entry a specific detail line instead of a generic
    /// "medicine updated" message.
    static func changeDescription(from previous: Medicine, to updated: Medicine) -> String {
        var changes: [String] = []
        if previous.name != updated.name {
            changes.append("Name changed from \"\(previous.name)\" to \"\(updated.name)\"")
        }
        if previous.stock != updated.stock {
            changes.append("Stock changed from \(previous.stock) to \(updated.stock)")
        }
        if previous.aisle != updated.aisle {
            changes.append("Aisle changed from \"\(previous.aisle)\" to \"\(updated.aisle)\"")
        }
        return changes.isEmpty ? "No changes" : changes.joined(separator: "; ")
    }

    /// Compares every field, including `id`, so `MedicineDetailView` can tell whether the
    /// edited copy differs from the last-saved one.
    static func == (lhs: Medicine, rhs: Medicine) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.stock == rhs.stock &&
               lhs.aisle == rhs.aisle
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(stock)
        hasher.combine(aisle)
    }
}
