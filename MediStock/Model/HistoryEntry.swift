//
//  HistoryEntry.swift
//  MediStock
//
//  Created by Mathieu Arrio on 2026/08/18.
//

import Foundation
import FirebaseFirestoreSwift

/// One audit-trail record in the `history` collection, written atomically with every
/// add, update or delete of a `Medicine`.
struct HistoryEntry: Identifiable, Codable {
    @DocumentID var id: String?
    /// The `Medicine` this entry is about.
    var medicineId: String
    /// `User.identifier` of whoever made the change.
    var user: String
    /// Short headline, e.g. `Updated Doliprane`.
    var action: String
    /// Longer explanation, e.g. which fields changed (see `Medicine.changeDescription`).
    var details: String
    var timestamp: Date

    init(id: String? = nil, medicineId: String, user: String, action: String, details: String, timestamp: Date = Date()) {
        self.id = id
        self.medicineId = medicineId
        self.user = user
        self.action = action
        self.details = details
        self.timestamp = timestamp
    }
}
