//
//  MedicineStockViewModel.swift
//  MediStock
//
//  Created by Mathieu Arrio on 2026/08/18.
//

import Foundation
import Observation

/// Screen-facing state and actions for the medicine stock. It holds three independent
/// live views of the data (all medicines, a filtered/sorted page, one aisle's page),
/// validates input, and turns repository failures into `errorMessage`. All persistence
/// goes through `MedicineRepository`, so tests can inject a mock.
@Observable
@MainActor
final class MedicineStockViewModel {
    /// Every medicine, live. Backs the aisle list and `aisles`.
    var medicines: [Medicine] = []
    /// The currently loaded page for the "All Medicines" screen, after filter and sort.
    var filteredMedicines: [Medicine] = []
    /// The currently loaded page for the aisle selected via `fetchMedicines(inAisle:)`.
    var medicinesInAisle: [Medicine] = []
    /// History of the medicine last passed to `fetchHistory(for:)`, newest first.
    var history: [HistoryEntry] = []
    /// Message for the error alert; set whenever a repository call or validation fails.
    var errorMessage: String?

    @ObservationIgnored
    private let repository: MedicineRepository

    /// Number of documents fetched per page when lazy-loading a list.
    private let pageSize = 20

    var isLoadingMoreFilteredMedicines = false
    var hasMoreFilteredMedicines = true
    var isLoadingMoreAisleMedicines = false
    var hasMoreAisleMedicines = true

    // Live-query registrations. `nonisolated(unsafe)` lets the nonisolated `deinit` cancel
    // them; they are otherwise only touched on the main actor.
    @ObservationIgnored
    private nonisolated(unsafe) var medicinesListener: ListenerToken?
    @ObservationIgnored
    private nonisolated(unsafe) var filteredMedicinesListener: ListenerToken?
    @ObservationIgnored
    private nonisolated(unsafe) var aisleMedicinesListener: ListenerToken?

    // Query parameters remembered so a page can be re-run with a larger limit while the
    // user scrolls. Not observed: views never read them.
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

    /// The distinct aisle names across all medicines, sorted alphabetically.
    var aisles: [String] {
        Array(Set(medicines.map { $0.aisle })).sorted()
    }

    // MARK: - Validation

    /// A name is valid when it has at least one non-whitespace character.
    func isValidName(_ name: String) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Stock can be zero but never negative.
    func isValidStock(_ stock: Int) -> Bool {
        stock >= 0
    }

    /// An aisle is valid when it has at least one non-whitespace character.
    func isValidAisle(_ aisle: String) -> Bool {
        !aisle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// True when name, stock and aisle are all valid; `addMedicine` and `updateMedicine`
    /// refuse to save anything else.
    func isValidMedicine(_ medicine: Medicine) -> Bool {
        isValidName(medicine.name) && isValidStock(medicine.stock) && isValidAisle(medicine.aisle)
    }

    // MARK: - Fetching

    /// Starts the live listener that keeps `medicines` up to date. Safe to call more than
    /// once; only the first call registers a listener.
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

    /// Loads the medicine's history into `history`. Does nothing for an unsaved medicine.
    func fetchHistory(for medicine: Medicine) async {
        guard let medicineId = medicine.id else { return }
        do {
            history = try await repository.history(forMedicineId: medicineId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Cancels all live listeners. Calling a `fetch…` method afterwards starts them again.
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

    // MARK: - Writes
    //
    // Each write takes the acting user's `identifier`, recorded in the history entry the
    // repository writes alongside it. Failures surface through `errorMessage`.

    /// Validates then saves a new medicine together with its "added" history entry.
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

    /// Deletes the medicines at `offsets` of the full `medicines` array (not of a filtered
    /// or aisle page).
    func deleteMedicines(at offsets: IndexSet, user: String) async {
        let medicinesToDelete = offsets.map { medicines[$0] }
        do {
            try await repository.deleteMedicines(medicinesToDelete, user: user)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Deletes a single medicine and records a matching history entry, for the
    /// swipe-to-delete row action. Unlike `deleteMedicines(at:)` it takes the medicine
    /// itself, so it works from any list regardless of filtering or paging.
    func deleteMedicine(_ medicine: Medicine, user: String) async {
        guard medicine.id != nil else { return }
        do {
            try await repository.deleteMedicines([medicine], user: user)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Validates then saves an edited medicine, and refreshes `history` so the new entry
    /// shows up. Does nothing for a medicine that has never been saved.
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
