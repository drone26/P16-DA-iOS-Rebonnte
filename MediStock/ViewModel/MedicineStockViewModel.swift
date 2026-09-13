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
    var history: [HistoryEntry] = []
    private let db = Firestore.firestore()

    private nonisolated(unsafe) var medicinesListener: ListenerRegistration?

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
            self.medicines = querySnapshot?.documents.compactMap { document in
                try? document.data(as: Medicine.self)
            } ?? []
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
    }

    deinit {
        medicinesListener?.remove()
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

    func filteredAndSortedMedicines(filterText: String, sortOption: SortOption) -> [Medicine] {
        var result = medicines

        if !filterText.isEmpty {
            result = result.filter { $0.name.lowercased().contains(filterText.lowercased()) }
        }

        switch sortOption {
        case .name:
            result.sort { $0.name.lowercased() < $1.name.lowercased() }
        case .stock:
            result.sort { $0.stock < $1.stock }
        case .none:
            break
        }

        return result
    }
}
