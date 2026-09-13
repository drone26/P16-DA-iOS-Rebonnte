//
//  FirestoreMedicineRepository.swift
//  MediStock
//
//  Created by Mathieu Arrio on 2026/08/30.
//

import Foundation
import Firebase
import FirebaseFirestoreSwift

/// Production `MedicineRepository` backed by Cloud Firestore. This is the only
/// place in the app that knows about `Firestore`, queries, batches and
/// transactions — the ViewModel talks to the protocol, and tests substitute an
/// in-memory mock.
@MainActor
final class FirestoreMedicineRepository: MedicineRepository {
    private let db = Firestore.firestore()

    // MARK: - Observation

    func observeAllMedicines(
        onChange: @escaping ([Medicine]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> ListenerToken {
        let registration = db.collection("medicines").addSnapshotListener { querySnapshot, error in
            Task { @MainActor in
                if let error {
                    onError(error)
                    return
                }
                let documents = querySnapshot?.documents ?? []
                onChange(documents.compactMap { try? $0.data(as: Medicine.self) })
            }
        }
        return ClosureListenerToken { registration.remove() }
    }

    func observeMedicines(
        matching filter: String,
        sortedBy sort: SortOption,
        limit: Int,
        onChange: @escaping (_ medicines: [Medicine], _ hasMore: Bool) -> Void,
        onError: @escaping (Error) -> Void
    ) -> ListenerToken {
        let trimmedFilter = filter.trimmingCharacters(in: .whitespacesAndNewlines)
        var query: Query = db.collection("medicines")

        if !trimmedFilter.isEmpty {
            // Prefix match, straight from Firestore: every `name` in the half-open
            // range [filter, filter + <max code point>). "\u{f8ff}" sorts after any
            // normal character, so it acts as the upper bound of the prefix.
            query = query
                .whereField("name", isGreaterThanOrEqualTo: trimmedFilter)
                .whereField("name", isLessThan: trimmedFilter + "\u{f8ff}")
        }
        switch sort {
        case .name:
            query = query.order(by: "name")
        case .stock:
            // A range filter forces `name` to be the first ordering; keep the stock
            // sort as the secondary key. With no filter, sort by stock directly.
            query = trimmedFilter.isEmpty
                ? query.order(by: "stock")
                : query.order(by: "name").order(by: "stock")
        case .none:
            break
        }

        return listenPaginated(query, limit: limit, onChange: onChange, onError: onError)
    }

    func observeMedicines(
        inAisle aisle: String,
        limit: Int,
        onChange: @escaping (_ medicines: [Medicine], _ hasMore: Bool) -> Void,
        onError: @escaping (Error) -> Void
    ) -> ListenerToken {
        let query = db.collection("medicines").whereField("aisle", isEqualTo: aisle)
        return listenPaginated(query, limit: limit, onChange: onChange, onError: onError)
    }

    /// Runs `query` limited to `limit`, reporting the decoded page plus whether a full
    /// page came back (i.e. there may be more). Shared by the filtered and aisle-scoped
    /// queries so they don't each duplicate decoding and the "has more" rule.
    private func listenPaginated(
        _ query: Query,
        limit: Int,
        onChange: @escaping (_ medicines: [Medicine], _ hasMore: Bool) -> Void,
        onError: @escaping (Error) -> Void
    ) -> ListenerToken {
        let registration = query.limit(to: limit).addSnapshotListener { querySnapshot, error in
            Task { @MainActor in
                if let error {
                    onError(error)
                    return
                }
                let documents = querySnapshot?.documents ?? []
                let medicines = documents.compactMap { try? $0.data(as: Medicine.self) }
                onChange(medicines, documents.count >= limit)
            }
        }
        return ClosureListenerToken { registration.remove() }
    }

    // MARK: - Writes

    /// Writes the new medicine and its history entry as a single atomic batch so the
    /// two can never diverge.
    func addMedicine(_ medicine: Medicine, user: String) async throws {
        let medicineRef = db.collection("medicines").document(medicine.id ?? UUID().uuidString)
        let batch = db.batch()
        try batch.setData(from: medicine, forDocument: medicineRef)
        try Self.addHistoryEntry(to: batch, db: db, action: "Added \(medicine.name)", user: user, medicineId: medicineRef.documentID, details: "Added new medicine")
        try await batch.commit()
    }

    /// Deletes each medicine and records one history entry per deletion, all in a
    /// single atomic batch so a deletion can never go unrecorded.
    func deleteMedicines(_ medicines: [Medicine], user: String) async throws {
        let batch = db.batch()
        for medicine in medicines {
            guard let id = medicine.id else { continue }
            batch.deleteDocument(db.collection("medicines").document(id))
            try Self.addHistoryEntry(to: batch, db: db, action: "Deleted \(medicine.name)", user: user, medicineId: id, details: "Deleted medicine")
        }
        try await batch.commit()
    }

    /// Runs the update as a transaction so the history entry can describe exactly which
    /// fields changed, read from the server's current state rather than the caller's
    /// local copy.
    func updateMedicine(_ medicine: Medicine, user: String) async throws {
        guard let id = medicine.id else { return }
        let medicineRef = db.collection("medicines").document(id)
        let historyRef = db.collection("history").document()
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
            let details = previous.map { Medicine.changeDescription(from: $0, to: medicine) } ?? "Updated medicine details"
            let history = HistoryEntry(id: historyRef.documentID, medicineId: id, user: user, action: "Updated \(medicine.name)", details: details)
            do {
                try transaction.setData(from: history, forDocument: historyRef)
            } catch let encodeError as NSError {
                errorPointer?.pointee = encodeError
                return nil
            }
            return nil
        }
    }

    // MARK: - History

    func history(forMedicineId id: String) async throws -> [HistoryEntry] {
        // Sorted client-side rather than via Firestore `order(by:)`: combining it with
        // the `medicineId` equality filter would need a composite index, and a single
        // medicine's history is small enough that sorting the fetched page locally is
        // cheap.
        let snapshot = try await db.collection("history")
            .whereField("medicineId", isEqualTo: id)
            .getDocuments()
        return snapshot.documents
            .compactMap { try? $0.data(as: HistoryEntry.self) }
            .sorted { $0.timestamp > $1.timestamp }
    }

    /// Adds a history-entry write to `batch` so it commits atomically alongside the
    /// medicine write it documents.
    private static func addHistoryEntry(to batch: WriteBatch, db: Firestore, action: String, user: String, medicineId: String, details: String) throws {
        let historyRef = db.collection("history").document()
        let history = HistoryEntry(id: historyRef.documentID, medicineId: medicineId, user: user, action: action, details: details)
        try batch.setData(from: history, forDocument: historyRef)
    }
}
