//
//  MedicineStockViewModel.swift
//  MediStock
//
//  Created by Mathieu Arrio on 2026/08/18.
//

import Foundation
import Observation
import Firebase

enum SortOption: String, CaseIterable, Identifiable {
    case none
    case name
    case stock

    var id: String { self.rawValue }
}

@Observable
@MainActor
final class MedicineStockViewModel {
    var medicines: [Medicine] = []
    var filteredMedicines: [Medicine] = []
    var medicinesInAisle: [Medicine] = []
    var history: [HistoryEntry] = []
    var errorMessage: String?
    private let db = Firestore.firestore()

    /// Number of documents fetched per page when lazy-loading a list.
    private let pageSize = 20

    var isLoadingMoreFilteredMedicines = false
    var hasMoreFilteredMedicines = true
    var isLoadingMoreAisleMedicines = false
    var hasMoreAisleMedicines = true

    @ObservationIgnored
    private nonisolated(unsafe) var medicinesListener: ListenerRegistration?
    @ObservationIgnored
    private nonisolated(unsafe) var filteredMedicinesListener: ListenerRegistration?
    @ObservationIgnored
    private nonisolated(unsafe) var aisleMedicinesListener: ListenerRegistration?

    @ObservationIgnored
    private var currentFilterText = ""
    @ObservationIgnored
    private var currentSortOption: SortOption = .none
    @ObservationIgnored
    private var filteredMedicinesLimit = 0
    @ObservationIgnored
    private var currentAisle = ""
    @ObservationIgnored
    private var aisleMedicinesLimit = 0

    var aisles: [String] {
        Array(Set(medicines.map { $0.aisle })).sorted()
    }

    func isValidName(_ name: String) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func isValidStock(_ stock: Int) -> Bool {
        stock >= 0
    }

    func isValidAisle(_ aisle: String) -> Bool {
        !aisle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func isValidMedicine(_ medicine: Medicine) -> Bool {
        isValidName(medicine.name) && isValidStock(medicine.stock) && isValidAisle(medicine.aisle)
    }

    func fetchMedicines() {
        guard medicinesListener == nil else { return }
        medicinesListener = db.collection("medicines").addSnapshotListener { [weak self] querySnapshot, error in
            guard let self else { return }
            if let error {
                self.errorMessage = error.localizedDescription
                return
            }
            let documents = querySnapshot?.documents ?? []
            self.medicines = documents.compactMap { document in
                try? document.data(as: Medicine.self)
            }
            self.backfillMissingNameSubstrings(in: documents)
        }
    }

    /// Self-heals documents written before `nameSubstrings` existed (or created outside
    /// the app) so they remain findable by `fetchFilteredAndSortedMedicines`'s
    /// `arrayContains` search.
    private func backfillMissingNameSubstrings(in documents: [QueryDocumentSnapshot]) {
        for document in documents {
            guard document.data()["nameSubstrings"] == nil,
                  let medicine = try? document.data(as: Medicine.self) else { continue }
            let substrings = Medicine.substrings(of: medicine.name)
            Task {
                do {
                    try await document.reference.updateData(["nameSubstrings": substrings])
                } catch {
                    print("Error backfilling nameSubstrings: \(error)")
                }
            }
        }
    }

    /// Filters and sorts medicines server-side using Firestore query constraints instead
    /// of loading everything and filtering/sorting in Swift. A non-empty filter matches
    /// `nameSubstrings` (precomputed substrings of the name, see `Medicine.substrings`)
    /// via `arrayContains`, so it can match text found anywhere in the name, not just a
    /// leading prefix. Combining `arrayContains` with `order(by:)` on a different field
    /// needs a Firestore composite index (see `firestore.indexes.json`), which is what
    /// lets sorting stay server-side even while a filter is active.
    ///
    /// Only the first `pageSize` results are loaded initially; call
    /// `loadMoreFilteredMedicinesIfNeeded(currentItem:)` as the user scrolls to lazily
    /// widen the query instead of fetching the whole collection up front.
    func fetchFilteredAndSortedMedicines(filterText: String, sortOption: SortOption) {
        currentFilterText = filterText
        currentSortOption = sortOption
        filteredMedicinesLimit = pageSize
        hasMoreFilteredMedicines = true
        runFilteredMedicinesQuery()
    }

    /// Call from the list row's `onAppear`; widens the page once the user scrolls near
    /// the end of the currently loaded results.
    func loadMoreFilteredMedicinesIfNeeded(currentItem medicine: Medicine) {
        guard hasMoreFilteredMedicines, !isLoadingMoreFilteredMedicines,
              isNearEnd(of: filteredMedicines, item: medicine) else { return }

        isLoadingMoreFilteredMedicines = true
        filteredMedicinesLimit += pageSize
        runFilteredMedicinesQuery()
    }

    private func runFilteredMedicinesQuery() {
        let trimmedFilter = currentFilterText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var query: Query = db.collection("medicines")

        if !trimmedFilter.isEmpty {
            query = query.whereField("nameSubstrings", arrayContains: trimmedFilter)
        }
        switch currentSortOption {
        case .name:
            query = query.order(by: "name")
        case .stock:
            query = query.order(by: "stock")
        case .none:
            break
        }

        listenPaginated(query, limit: filteredMedicinesLimit, listener: \.filteredMedicinesListener) { [weak self] medicines, hasMore in
            guard let self else { return }
            self.isLoadingMoreFilteredMedicines = false
            self.hasMoreFilteredMedicines = hasMore
            self.filteredMedicines = medicines
        }
    }

    /// Fetches only the medicines for a given aisle using a Firestore `whereField` query.
    /// Only the first `pageSize` results are loaded initially; call
    /// `loadMoreAisleMedicinesIfNeeded(currentItem:)` as the user scrolls to lazily widen
    /// the query instead of fetching the whole aisle up front.
    func fetchMedicines(inAisle aisle: String) {
        currentAisle = aisle
        aisleMedicinesLimit = pageSize
        hasMoreAisleMedicines = true
        runAisleMedicinesQuery()
    }

    /// Call from the list row's `onAppear`; widens the page once the user scrolls near
    /// the end of the currently loaded results.
    func loadMoreAisleMedicinesIfNeeded(currentItem medicine: Medicine) {
        guard hasMoreAisleMedicines, !isLoadingMoreAisleMedicines,
              isNearEnd(of: medicinesInAisle, item: medicine) else { return }

        isLoadingMoreAisleMedicines = true
        aisleMedicinesLimit += pageSize
        runAisleMedicinesQuery()
    }

    private func runAisleMedicinesQuery() {
        let query = db.collection("medicines").whereField("aisle", isEqualTo: currentAisle)

        listenPaginated(query, limit: aisleMedicinesLimit, listener: \.aisleMedicinesListener) { [weak self] medicines, hasMore in
            guard let self else { return }
            self.isLoadingMoreAisleMedicines = false
            self.hasMoreAisleMedicines = hasMore
            self.medicinesInAisle = medicines
        }
    }

    /// True once `item` is within `threshold` positions of the end of `items`, i.e. close
    /// enough to the bottom of the currently loaded page to justify fetching the next one.
    private func isNearEnd(of items: [Medicine], item: Medicine, threshold: Int = 5) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return false }
        let thresholdIndex = items.index(items.endIndex, offsetBy: -threshold, limitedBy: items.startIndex) ?? items.startIndex
        return index >= thresholdIndex
    }

    /// Runs `query` limited to `limit`, replacing whichever listener `listener` points to,
    /// and reports the decoded page plus whether a full page came back (i.e. there may be
    /// more). Shared by the filtered and aisle-scoped queries so they don't each duplicate
    /// listener teardown/decoding.
    private func listenPaginated(
        _ query: Query,
        limit: Int,
        listener: ReferenceWritableKeyPath<MedicineStockViewModel, ListenerRegistration?>,
        onUpdate: @escaping (_ medicines: [Medicine], _ hasMore: Bool) -> Void
    ) {
        self[keyPath: listener]?.remove()
        self[keyPath: listener] = query.limit(to: limit).addSnapshotListener { [weak self] querySnapshot, error in
            guard let self else { return }
            if let error {
                self.errorMessage = error.localizedDescription
                return
            }
            let documents = querySnapshot?.documents ?? []
            let medicines = documents.compactMap { try? $0.data(as: Medicine.self) }
            onUpdate(medicines, documents.count >= limit)
        }
    }

    func fetchHistory(for medicine: Medicine) {
        guard let medicineId = medicine.id else { return }
        let db = self.db
        Task { [weak self] in
            do {
                // Sorted client-side rather than via Firestore `order(by:)`: combining it with
                // the `medicineId` equality filter would need a composite index provisioned
                // in the Firebase console, and a single medicine's history is small enough
                // that sorting the fetched page locally is cheap.
                let snapshot = try await db.collection("history")
                    .whereField("medicineId", isEqualTo: medicineId)
                    .getDocuments()
                self?.history = snapshot.documents
                    .compactMap { document in try? document.data(as: HistoryEntry.self) }
                    .sorted { $0.timestamp > $1.timestamp }
            } catch {
                self?.errorMessage = error.localizedDescription
            }
        }
    }

    func stopListening() {
        medicinesListener?.remove()
        medicinesListener = nil
        filteredMedicinesListener?.remove()
        filteredMedicinesListener = nil
        aisleMedicinesListener?.remove()
        aisleMedicinesListener = nil
    }

    deinit {
        medicinesListener?.remove()
        filteredMedicinesListener?.remove()
        aisleMedicinesListener?.remove()
    }

    /// Writes the new medicine and its history entry as a single atomic batch so the two
    /// can never diverge (e.g. the medicine being created but no matching history entry
    /// existing because the history write failed independently).
    func addRandomMedicine(user: String) {
        let medicine = Medicine(name: "Medicine \(Int.random(in: 1...100))", stock: Int.random(in: 1...100), aisle: "Aisle \(Int.random(in: 1...10))")
        let db = self.db
        Task { [weak self] in
            do {
                let medicineRef = db.collection("medicines").document(medicine.id ?? UUID().uuidString)
                let batch = db.batch()
                try batch.setData(from: medicine, forDocument: medicineRef)
                try Self.addHistoryEntry(to: batch, db: db, action: "Added \(medicine.name)", user: user, medicineId: medicineRef.documentID, details: "Added new medicine")
                try await batch.commit()
            } catch {
                self?.errorMessage = error.localizedDescription
            }
        }
    }

    /// Deletes the selected medicines and records one history entry per deletion, all in a
    /// single atomic batch so a deletion can never go unrecorded in the history.
    func deleteMedicines(at offsets: IndexSet, user: String) {
        let medicinesToDelete = offsets.map { medicines[$0] }
        let db = self.db
        Task { [weak self] in
            do {
                let batch = db.batch()
                for medicine in medicinesToDelete {
                    guard let id = medicine.id else { continue }
                    batch.deleteDocument(db.collection("medicines").document(id))
                    try Self.addHistoryEntry(to: batch, db: db, action: "Deleted \(medicine.name)", user: user, medicineId: id, details: "Deleted medicine")
                }
                try await batch.commit()
            } catch {
                self?.errorMessage = error.localizedDescription
            }
        }
    }

    /// Runs the update as a transaction so the history entry can describe exactly which
    /// fields changed (read from the server's current state, not from whatever the caller's
    /// local copy happens to hold) instead of a generic "medicine updated" message.
    func updateMedicine(_ medicine: Medicine, user: String) {
        guard let id = medicine.id else { return }
        guard isValidMedicine(medicine) else {
            errorMessage = "Please provide a non-empty name, a non-negative stock, and a non-empty aisle before saving."
            return
        }
        let db = self.db
        let medicineRef = db.collection("medicines").document(id)
        let historyRef = db.collection("history").document()
        Task { [weak self] in
            do {
                _ = try await db.runTransaction { transaction, errorPointer -> Any? in
                    let snapshot: DocumentSnapshot
                    do {
                        snapshot = try transaction.getDocument(medicineRef)
                    } catch let fetchError as NSError {
                        errorPointer?.pointee = fetchError
                        return nil
                    }
                    let previous = try? snapshot.data(as: Medicine.self)
                    do {
                        try transaction.setData(from: medicine, forDocument: medicineRef)
                    } catch let encodeError as NSError {
                        errorPointer?.pointee = encodeError
                        return nil
                    }
                    let details = previous.map { Self.describeChanges(from: $0, to: medicine) } ?? "Updated medicine details"
                    let history = HistoryEntry(id: historyRef.documentID, medicineId: id, user: user, action: "Updated \(medicine.name)", details: details)
                    do {
                        try transaction.setData(from: history, forDocument: historyRef)
                    } catch let encodeError as NSError {
                        errorPointer?.pointee = encodeError
                        return nil
                    }
                    return nil
                }
                self?.fetchHistory(for: medicine)
            } catch {
                self?.errorMessage = error.localizedDescription
            }
        }
    }

    /// Human-readable, field-by-field description of what changed between two revisions of
    /// the same medicine, e.g. "Name changed from \"Doliprane\" to \"Dolipranum\"".
    private static func describeChanges(from previous: Medicine, to updated: Medicine) -> String {
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

    /// Adds a history-entry write to `batch` so it commits atomically alongside the
    /// medicine write it documents, instead of as an independent Firestore call that could
    /// succeed or fail on its own and leave the action unrecorded.
    private static func addHistoryEntry(to batch: WriteBatch, db: Firestore, action: String, user: String, medicineId: String, details: String) throws {
        let historyRef = db.collection("history").document()
        let history = HistoryEntry(id: historyRef.documentID, medicineId: medicineId, user: user, action: action, details: details)
        try batch.setData(from: history, forDocument: historyRef)
    }
}
