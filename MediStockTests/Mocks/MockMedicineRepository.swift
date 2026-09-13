//
//  MockMedicineRepository.swift
//  MediStockTests
//
//  Created by Mathieu Arrio on 2026/08/30.
//

import Foundation
@testable import MediStock

/// In-memory `MedicineRepository` for unit tests. Captures the `observe…` callbacks
/// so a test can push updates synchronously via `emit…`, records every write, and
/// can be told to throw from the async methods.
@MainActor
final class MockMedicineRepository: MedicineRepository {

    // MARK: Captured observation callbacks

    private(set) var allMedicinesOnChange: (([Medicine]) -> Void)?
    private(set) var allMedicinesOnError: ((Error) -> Void)?

    private(set) var filteredOnChange: (([Medicine], Bool) -> Void)?
    private(set) var filteredOnError: ((Error) -> Void)?

    private(set) var aisleOnChange: (([Medicine], Bool) -> Void)?
    private(set) var aisleOnError: ((Error) -> Void)?

    // MARK: Recorded calls

    private(set) var observeAllCallCount = 0
    private(set) var lastFilter: String?
    private(set) var lastSort: SortOption?
    private(set) var lastFilteredLimit: Int?
    private(set) var lastAisle: String?
    private(set) var lastAisleLimit: Int?

    private(set) var addedMedicines: [Medicine] = []
    private(set) var deletedBatches: [[Medicine]] = []
    private(set) var updatedMedicines: [Medicine] = []
    private(set) var historyRequestedIds: [String] = []
    private(set) var cancelledTokenCount = 0

    // MARK: Stubs

    var errorToThrow: Error?
    var stubHistory: [HistoryEntry] = []

    private func makeToken() -> ListenerToken {
        ClosureListenerToken { [weak self] in self?.cancelledTokenCount += 1 }
    }

    // MARK: MedicineRepository

    func observeAllMedicines(
        onChange: @escaping ([Medicine]) -> Void,
        onError: @escaping (Error) -> Void
    ) -> ListenerToken {
        observeAllCallCount += 1
        allMedicinesOnChange = onChange
        allMedicinesOnError = onError
        return makeToken()
    }

    func observeMedicines(
        matching filter: String,
        sortedBy sort: SortOption,
        limit: Int,
        onChange: @escaping ([Medicine], Bool) -> Void,
        onError: @escaping (Error) -> Void
    ) -> ListenerToken {
        lastFilter = filter
        lastSort = sort
        lastFilteredLimit = limit
        filteredOnChange = onChange
        filteredOnError = onError
        return makeToken()
    }

    func observeMedicines(
        inAisle aisle: String,
        limit: Int,
        onChange: @escaping ([Medicine], Bool) -> Void,
        onError: @escaping (Error) -> Void
    ) -> ListenerToken {
        lastAisle = aisle
        lastAisleLimit = limit
        aisleOnChange = onChange
        aisleOnError = onError
        return makeToken()
    }

    func addMedicine(_ medicine: Medicine, user: String) async throws {
        if let errorToThrow { throw errorToThrow }
        addedMedicines.append(medicine)
    }

    func deleteMedicines(_ medicines: [Medicine], user: String) async throws {
        if let errorToThrow { throw errorToThrow }
        deletedBatches.append(medicines)
    }

    func updateMedicine(_ medicine: Medicine, user: String) async throws {
        if let errorToThrow { throw errorToThrow }
        updatedMedicines.append(medicine)
    }

    func history(forMedicineId id: String) async throws -> [HistoryEntry] {
        historyRequestedIds.append(id)
        if let errorToThrow { throw errorToThrow }
        return stubHistory
    }

    // MARK: Test helpers

    func emitAllMedicines(_ medicines: [Medicine]) {
        allMedicinesOnChange?(medicines)
    }

    func emitAllMedicinesError(_ error: Error) {
        allMedicinesOnError?(error)
    }

    func emitFilteredMedicines(_ medicines: [Medicine], hasMore: Bool) {
        filteredOnChange?(medicines, hasMore)
    }

    func emitFilteredMedicinesError(_ error: Error) {
        filteredOnError?(error)
    }

    func emitAisleMedicines(_ medicines: [Medicine], hasMore: Bool) {
        aisleOnChange?(medicines, hasMore)
    }

    func emitAisleMedicinesError(_ error: Error) {
        aisleOnError?(error)
    }
}
