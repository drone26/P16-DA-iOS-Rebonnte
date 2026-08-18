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

    func fetchMedicines() {
        guard medicinesListener == nil else { return }
        medicinesListener = db.collection("medicines").addSnapshotListener { [weak self] querySnapshot, error in
            guard let self else { return }
            if let error {
                print("Error getting documents: \(error)")
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
    /// of loading everything and filtering in Swift. A non-empty filter matches
    /// `nameSubstrings` (precomputed substrings of the name, see `Medicine.substrings`)
    /// via `arrayContains`, so it can match text found anywhere in the name, not just a
    /// leading prefix. Combining `arrayContains` with `order(by:)` on a different field
    /// needs a Firestore composite index, so when a filter is active, sorting is applied
    /// locally to the already server-filtered (small) result instead.
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
        } else if currentSortOption == .name {
            query = query.order(by: "name")
        } else if currentSortOption == .stock {
            query = query.order(by: "stock")
        }

        listenPaginated(query, limit: filteredMedicinesLimit, listener: \.filteredMedicinesListener) { [weak self] medicines, hasMore in
            guard let self else { return }
            self.isLoadingMoreFilteredMedicines = false
            self.hasMoreFilteredMedicines = hasMore

            var results = medicines
            if !trimmedFilter.isEmpty {
                switch self.currentSortOption {
                case .name:
                    results.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                case .stock:
                    results.sort { $0.stock < $1.stock }
                case .none:
                    break
                }
            }

            self.filteredMedicines = results
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
            guard self != nil else { return }
            if let error {
                print("Error getting documents: \(error)")
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
                let snapshot = try await db.collection("history")
                    .whereField("medicineId", isEqualTo: medicineId)
                    .getDocuments()
                self?.history = snapshot.documents.compactMap { document in
                    try? document.data(as: HistoryEntry.self)
                }
            } catch {
                print("Error getting history: \(error)")
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

    func addRandomMedicine(user: String) {
        let medicine = Medicine(name: "Medicine \(Int.random(in: 1...100))", stock: Int.random(in: 1...100), aisle: "Aisle \(Int.random(in: 1...10))")
        let db = self.db
        Task {
            do {
                try db.collection("medicines").document(medicine.id ?? UUID().uuidString).setData(from: medicine)
                await Self.addHistory(db: db, action: "Added \(medicine.name)", user: user, medicineId: medicine.id ?? "", details: "Added new medicine")
            } catch {
                print("Error adding document: \(error)")
            }
        }
    }

    func deleteMedicines(at offsets: IndexSet) {
        let medicinesToDelete = offsets.map { medicines[$0] }
        let db = self.db
        Task {
            for medicine in medicinesToDelete {
                guard let id = medicine.id else { continue }
                do {
                    try await db.collection("medicines").document(id).delete()
                } catch {
                    print("Error removing document: \(error)")
                }
            }
        }
    }

    func increaseStock(_ medicine: Medicine, user: String) {
        updateStock(medicine, by: 1, user: user)
    }

    func decreaseStock(_ medicine: Medicine, user: String) {
        updateStock(medicine, by: -1, user: user)
    }

    private func updateStock(_ medicine: Medicine, by amount: Int, user: String) {
        guard let id = medicine.id else { return }
        let newStock = medicine.stock + amount
        let db = self.db
        Task { [weak self] in
            do {
                try await db.collection("medicines").document(id).updateData(["stock": newStock])
                self?.applyStockUpdate(id: id, newStock: newStock)
                await Self.addHistory(db: db, action: "\(amount > 0 ? "Increased" : "Decreased") stock of \(medicine.name) by \(amount)", user: user, medicineId: id, details: "Stock changed from \(medicine.stock - amount) to \(newStock)")
                self?.fetchHistory(for: medicine)
            } catch {
                print("Error updating stock: \(error)")
            }
        }
    }

    private func applyStockUpdate(id: String, newStock: Int) {
        if let index = medicines.firstIndex(where: { $0.id == id }) {
            medicines[index].stock = newStock
        }
    }

    func updateMedicine(_ medicine: Medicine, user: String) {
        guard let id = medicine.id else { return }
        let db = self.db
        Task { [weak self] in
            do {
                try db.collection("medicines").document(id).setData(from: medicine)
                await Self.addHistory(db: db, action: "Updated \(medicine.name)", user: user, medicineId: id, details: "Updated medicine details")
                self?.fetchHistory(for: medicine)
            } catch {
                print("Error updating document: \(error)")
            }
        }
    }

    private static func addHistory(db: Firestore, action: String, user: String, medicineId: String, details: String) async {
        let history = HistoryEntry(medicineId: medicineId, user: user, action: action, details: details)
        do {
            try db.collection("history").document(history.id ?? UUID().uuidString).setData(from: history)
        } catch {
            print("Error adding history: \(error)")
        }
    }
}
