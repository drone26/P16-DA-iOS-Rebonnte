//
//  MedicineStockViewModel.swift
//  MediStock
//
//  Created by Mathieu Arrio on 2026/08/18.
//

import Foundation
import Observation

@Observable
@MainActor
final class MedicineStockViewModel {
    var medicines: [Medicine] = []
    var filteredMedicines: [Medicine] = []
    var medicinesInAisle: [Medicine] = []
    var history: [HistoryEntry] = []
    var errorMessage: String?

    @ObservationIgnored
    private let repository: MedicineRepository

    /// Number of documents fetched per page when lazy-loading a list.
    private let pageSize = 20

    var isLoadingMoreFilteredMedicines = false
    var hasMoreFilteredMedicines = true
    var isLoadingMoreAisleMedicines = false
    var hasMoreAisleMedicines = true

    @ObservationIgnored
    private nonisolated(unsafe) var medicinesListener: ListenerToken?
    @ObservationIgnored
    private nonisolated(unsafe) var filteredMedicinesListener: ListenerToken?
    @ObservationIgnored
    private nonisolated(unsafe) var aisleMedicinesListener: ListenerToken?

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

    convenience init() {
        self.init(repository: FirestoreMedicineRepository())
    }

    init(repository: MedicineRepository) {
        self.repository = repository
    }

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
        medicinesListener = repository.observeAllMedicines { [weak self] medicines in
            self?.medicines = medicines
        } onError: { [weak self] error in
            self?.errorMessage = error.localizedDescription
        }
    }

    /// Filters and sorts medicines server-side, loading only the first `pageSize`
    /// results. Call `loadMoreFilteredMedicinesIfNeeded(currentItem:)` as the user
    /// scrolls to lazily widen the query.
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
        filteredMedicinesListener?.cancel()
        filteredMedicinesListener = repository.observeMedicines(
            matching: currentFilterText,
            sortedBy: currentSortOption,
            limit: filteredMedicinesLimit
        ) { [weak self] medicines, hasMore in
            guard let self else { return }
            self.isLoadingMoreFilteredMedicines = false
            self.hasMoreFilteredMedicines = hasMore
            self.filteredMedicines = medicines
        } onError: { [weak self] error in
            self?.errorMessage = error.localizedDescription
        }
    }

    /// Fetches only the medicines for a given aisle, loading only the first `pageSize`
    /// results. Call `loadMoreAisleMedicinesIfNeeded(currentItem:)` as the user scrolls
    /// to lazily widen the query.
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
        aisleMedicinesListener?.cancel()
        aisleMedicinesListener = repository.observeMedicines(
            inAisle: currentAisle,
            limit: aisleMedicinesLimit
        ) { [weak self] medicines, hasMore in
            guard let self else { return }
            self.isLoadingMoreAisleMedicines = false
            self.hasMoreAisleMedicines = hasMore
            self.medicinesInAisle = medicines
        } onError: { [weak self] error in
            self?.errorMessage = error.localizedDescription
        }
    }

    /// True once `item` is within `threshold` positions of the end of `items`, i.e. close
    /// enough to the bottom of the currently loaded page to justify fetching the next one.
    func isNearEnd(of items: [Medicine], item: Medicine, threshold: Int = 5) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return false }
        let thresholdIndex = items.index(items.endIndex, offsetBy: -threshold, limitedBy: items.startIndex) ?? items.startIndex
        return index >= thresholdIndex
    }

    func fetchHistory(for medicine: Medicine) async {
        guard let medicineId = medicine.id else { return }
        do {
            history = try await repository.history(forMedicineId: medicineId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopListening() {
        medicinesListener?.cancel()
        medicinesListener = nil
        filteredMedicinesListener?.cancel()
        filteredMedicinesListener = nil
        aisleMedicinesListener?.cancel()
        aisleMedicinesListener = nil
    }

    deinit {
        medicinesListener?.cancel()
        filteredMedicinesListener?.cancel()
        aisleMedicinesListener?.cancel()
    }

    func addMedicine(_ medicine: Medicine, user: String) async {
        guard isValidMedicine(medicine) else {
            errorMessage = "Please provide a non-empty name, a non-negative stock, and a non-empty aisle before saving."
            return
        }
        do {
            try await repository.addMedicine(medicine, user: user)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteMedicines(at offsets: IndexSet, user: String) async {
        let medicinesToDelete = offsets.map { medicines[$0] }
        do {
            try await repository.deleteMedicines(medicinesToDelete, user: user)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Deletes a single medicine and records a matching history entry, for the
    /// swipe-to-delete row action.
    func deleteMedicine(_ medicine: Medicine, user: String) async {
        guard medicine.id != nil else { return }
        do {
            try await repository.deleteMedicines([medicine], user: user)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateMedicine(_ medicine: Medicine, user: String) async {
        guard medicine.id != nil else { return }
        guard isValidMedicine(medicine) else {
            errorMessage = "Please provide a non-empty name, a non-negative stock, and a non-empty aisle before saving."
            return
        }
        do {
            try await repository.updateMedicine(medicine, user: user)
            await fetchHistory(for: medicine)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
