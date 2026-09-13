//
//  MedicineRepository.swift
//  MediStock
//
//  Created by Mathieu Arrio on 2026/08/30.
//

import Foundation

/// The persistence operations `MedicineStockViewModel` needs, expressed purely in
/// terms of the app's own model types. `FirestoreMedicineRepository` is the
/// production implementation; tests inject an in-memory mock so no unit test ever
/// touches the real Firebase project.
///
/// All `observe…` callbacks are delivered on the main actor so the ViewModel can
/// assign straight to its `@Observable` state without hopping threads.
@MainActor
protocol MedicineRepository {
    /// Live view of the whole `medicines` collection.
    func observeAllMedicines(
        onChange: @escaping ([Medicine]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> ListenerToken

    /// Live, paginated view of the medicines matching `filter` (matched anywhere in
    /// the name) ordered by `sort`, capped at `limit` documents. `hasMore` is true
    /// when a full page came back, i.e. widening `limit` may surface more rows.
    func observeMedicines(
        matching filter: String,
        sortedBy sort: SortOption,
        limit: Int,
        onChange: @escaping (_ medicines: [Medicine], _ hasMore: Bool) -> Void,
        onError: @escaping (Error) -> Void
    ) -> ListenerToken

    /// Live, paginated view of a single aisle's medicines, capped at `limit`.
    func observeMedicines(
        inAisle aisle: String,
        limit: Int,
        onChange: @escaping (_ medicines: [Medicine], _ hasMore: Bool) -> Void,
        onError: @escaping (Error) -> Void
    ) -> ListenerToken

    /// Persists a new medicine and its "added" history entry atomically.
    func addMedicine(_ medicine: Medicine, user: String) async throws

    /// Deletes each medicine and records one "deleted" history entry per deletion,
    /// all atomically. Medicines without an `id` are skipped.
    func deleteMedicines(_ medicines: [Medicine], user: String) async throws

    /// Persists an edited medicine and a history entry describing exactly which
    /// fields changed, atomically.
    func updateMedicine(_ medicine: Medicine, user: String) async throws

    /// The history entries for one medicine, newest first.
    func history(forMedicineId id: String) async throws -> [HistoryEntry]
}
