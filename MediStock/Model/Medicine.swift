//
//  Medicine.swift
//  MediStock
//
//  Created by Vincent Saluzzo on 28/05/2024.
//  Modified by Mathieu Arrio on 2026/08/18.
//

import Foundation
import FirebaseFirestoreSwift

struct Medicine: Identifiable, Codable, Equatable, Hashable {
    @DocumentID var id: String?
    var name: String {
        didSet {
            guard oldValue != name else { return }
            nameSubstrings = Medicine.substrings(of: name)
        }
    }
    var stock: Int
    var aisle: String
    /// Precomputed lowercase substrings of `name`, persisted to Firestore so a
    /// `whereField("nameSubstrings", arrayContains:)` query can match text found
    /// anywhere in the name rather than only a leading prefix. Optional so documents
    /// written before this field existed still decode instead of being dropped.
    var nameSubstrings: [String]?

    init(id: String? = nil, name: String, stock: Int, aisle: String) {
        self.id = id
        self.name = name
        self.stock = stock
        self.aisle = aisle
        self.nameSubstrings = Medicine.substrings(of: name)
    }

    static func substrings(of name: String) -> [String] {
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
