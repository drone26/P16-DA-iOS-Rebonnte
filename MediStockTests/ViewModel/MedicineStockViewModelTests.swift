//
//  MedicineStockViewModelTests.swift
//  MediStockTests
//
//  Created by Mathieu Arrio on 2026/08/30.
//

import XCTest
@testable import MediStock

@MainActor
final class MedicineStockViewModelTests: XCTestCase {

    private var repository: MockMedicineRepository!
    private var sut: MedicineStockViewModel!

    override func setUp() {
        super.setUp()
        repository = MockMedicineRepository()
        sut = MedicineStockViewModel(repository: repository)
    }

    override func tearDown() {
        sut = nil
        repository = nil
        super.tearDown()
    }

    private func medicine(_ id: String, name: String = "Med", stock: Int = 1, aisle: String = "A") -> Medicine {
        Medicine(id: id, name: name, stock: stock, aisle: aisle)
    }

    // MARK: - Validators

    func testIsValidName() {
        XCTAssertFalse(sut.isValidName(""))
        XCTAssertFalse(sut.isValidName("   \n"))
        XCTAssertTrue(sut.isValidName("Doliprane"))
    }

    func testIsValidStock() {
        XCTAssertFalse(sut.isValidStock(-1))
        XCTAssertTrue(sut.isValidStock(0))
        XCTAssertTrue(sut.isValidStock(42))
    }

    func testIsValidAisle() {
        XCTAssertFalse(sut.isValidAisle(" "))
        XCTAssertTrue(sut.isValidAisle("Aisle 1"))
    }

    func testIsValidMedicineComposesFieldValidators() {
        XCTAssertTrue(sut.isValidMedicine(medicine("1", name: "Doliprane", stock: 0, aisle: "A")))
        XCTAssertFalse(sut.isValidMedicine(medicine("1", name: "", stock: 0, aisle: "A")))
        XCTAssertFalse(sut.isValidMedicine(medicine("1", name: "Doliprane", stock: -1, aisle: "A")))
        XCTAssertFalse(sut.isValidMedicine(medicine("1", name: "Doliprane", stock: 0, aisle: "")))
    }

    // MARK: - aisles

    func testAislesAreDedupedAndSorted() {
        sut.fetchMedicines()
        repository.emitAllMedicines([
            medicine("1", aisle: "B"),
            medicine("2", aisle: "A"),
            medicine("3", aisle: "B"),
            medicine("4", aisle: "C"),
        ])
        XCTAssertEqual(sut.aisles, ["A", "B", "C"])
    }

    // MARK: - fetchMedicines

    func testFetchMedicinesRegistersListenerOnlyOnce() {
        sut.fetchMedicines()
        sut.fetchMedicines()
        XCTAssertEqual(repository.observeAllCallCount, 1)
    }

    func testFetchMedicinesUpdatesPublishedList() {
        sut.fetchMedicines()
        repository.emitAllMedicines([medicine("1"), medicine("2")])
        XCTAssertEqual(sut.medicines.map(\.id), ["1", "2"])
    }

    func testFetchMedicinesListenerErrorSetsErrorMessage() {
        sut.fetchMedicines()
        repository.emitAllMedicinesError(TestError.boom)
        XCTAssertEqual(sut.errorMessage, TestError.boom.localizedDescription)
    }

    // MARK: - Filtered pagination

    func testFetchFilteredResetsLimitAndRecordsQuery() {
        sut.fetchFilteredAndSortedMedicines(filterText: "dol", sortOption: .name)
        XCTAssertEqual(repository.lastFilter, "dol")
        XCTAssertEqual(repository.lastSort, .name)
        XCTAssertEqual(repository.lastFilteredLimit, 20)
        XCTAssertTrue(sut.hasMoreFilteredMedicines)
    }

    func testFilteredCallbackUpdatesState() {
        sut.fetchFilteredAndSortedMedicines(filterText: "", sortOption: .none)
        sut.isLoadingMoreFilteredMedicines = true
        repository.emitFilteredMedicines([medicine("1")], hasMore: false)

        XCTAssertEqual(sut.filteredMedicines.map(\.id), ["1"])
        XCTAssertFalse(sut.hasMoreFilteredMedicines)
        XCTAssertFalse(sut.isLoadingMoreFilteredMedicines)
    }

    func testLoadMoreFilteredWidensLimitWhenNearEnd() {
        sut.fetchFilteredAndSortedMedicines(filterText: "", sortOption: .none)
        let page = (0..<20).map { medicine("\($0)") }
        repository.emitFilteredMedicines(page, hasMore: true)

        sut.loadMoreFilteredMedicinesIfNeeded(currentItem: page[19])

        XCTAssertEqual(repository.lastFilteredLimit, 40)
        XCTAssertTrue(sut.isLoadingMoreFilteredMedicines)
    }

    func testLoadMoreFilteredIgnoredWhenNotNearEnd() {
        sut.fetchFilteredAndSortedMedicines(filterText: "", sortOption: .none)
        let page = (0..<20).map { medicine("\($0)") }
        repository.emitFilteredMedicines(page, hasMore: true)

        sut.loadMoreFilteredMedicinesIfNeeded(currentItem: page[0])

        XCTAssertEqual(repository.lastFilteredLimit, 20)
    }

    func testLoadMoreFilteredIgnoredWhenNoMorePages() {
        sut.fetchFilteredAndSortedMedicines(filterText: "", sortOption: .none)
        let page = (0..<20).map { medicine("\($0)") }
        repository.emitFilteredMedicines(page, hasMore: false)

        sut.loadMoreFilteredMedicinesIfNeeded(currentItem: page[19])

        XCTAssertEqual(repository.lastFilteredLimit, 20)
    }

    // MARK: - Aisle pagination

    func testFetchAisleRecordsQueryAndResetsLimit() {
        sut.fetchMedicines(inAisle: "A")
        XCTAssertEqual(repository.lastAisle, "A")
        XCTAssertEqual(repository.lastAisleLimit, 20)
        XCTAssertTrue(sut.hasMoreAisleMedicines)
    }

    func testAisleCallbackUpdatesState() {
        sut.fetchMedicines(inAisle: "A")
        repository.emitAisleMedicines([medicine("1", aisle: "A")], hasMore: true)
        XCTAssertEqual(sut.medicinesInAisle.map(\.id), ["1"])
        XCTAssertTrue(sut.hasMoreAisleMedicines)
    }

    func testLoadMoreAisleWidensLimitWhenNearEnd() {
        sut.fetchMedicines(inAisle: "A")
        let page = (0..<20).map { medicine("\($0)", aisle: "A") }
        repository.emitAisleMedicines(page, hasMore: true)

        sut.loadMoreAisleMedicinesIfNeeded(currentItem: page[19])

        XCTAssertEqual(repository.lastAisleLimit, 40)
    }

    // MARK: - addMedicine

    func testAddMedicineForwardsValidMedicine() async {
        let new = medicine("1", name: "Doliprane", stock: 3, aisle: "A")
        await sut.addMedicine(new, user: "u")
        XCTAssertEqual(repository.addedMedicines.map(\.id), ["1"])
        XCTAssertNil(sut.errorMessage)
    }

    func testAddMedicineRejectsInvalidMedicineWithoutCallingRepository() async {
        await sut.addMedicine(medicine("1", name: "", aisle: "A"), user: "u")
        XCTAssertTrue(repository.addedMedicines.isEmpty)
        XCTAssertNotNil(sut.errorMessage)
    }

    func testAddMedicineSurfacesRepositoryError() async {
        repository.errorToThrow = TestError.boom
        await sut.addMedicine(medicine("1", name: "Doliprane", stock: 3, aisle: "A"), user: "u")
        XCTAssertEqual(sut.errorMessage, TestError.boom.localizedDescription)
    }

    // MARK: - deleteMedicine(s)

    func testDeleteMedicineForwardsToRepository() async {
        await sut.deleteMedicine(medicine("1"), user: "u")
        XCTAssertEqual(repository.deletedBatches.last?.map(\.id), ["1"])
    }

    func testDeleteMedicineIgnoresMedicineWithoutId() async {
        await sut.deleteMedicine(Medicine(name: "No id", stock: 1, aisle: "A"), user: "u")
        XCTAssertTrue(repository.deletedBatches.isEmpty)
    }

    func testDeleteMedicinesAtOffsetsResolvesAgainstMedicines() async {
        sut.fetchMedicines()
        repository.emitAllMedicines([medicine("1"), medicine("2"), medicine("3")])

        await sut.deleteMedicines(at: IndexSet([0, 2]), user: "u")

        XCTAssertEqual(repository.deletedBatches.last?.map(\.id), ["1", "3"])
    }

    // MARK: - updateMedicine

    func testUpdateMedicineForwardsAndRefreshesHistory() async {
        repository.stubHistory = [
            HistoryEntry(id: "h1", medicineId: "1", user: "u", action: "Updated", details: "x")
        ]
        await sut.updateMedicine(medicine("1", name: "Doliprane", stock: 3, aisle: "A"), user: "u")

        XCTAssertEqual(repository.updatedMedicines.map(\.id), ["1"])
        XCTAssertEqual(sut.history.map(\.id), ["h1"])
    }

    func testUpdateMedicineRejectsInvalidMedicine() async {
        await sut.updateMedicine(medicine("1", name: "", aisle: "A"), user: "u")
        XCTAssertTrue(repository.updatedMedicines.isEmpty)
        XCTAssertNotNil(sut.errorMessage)
    }

    func testUpdateMedicineIgnoresMedicineWithoutId() async {
        await sut.updateMedicine(Medicine(name: "Doliprane", stock: 1, aisle: "A"), user: "u")
        XCTAssertTrue(repository.updatedMedicines.isEmpty)
        XCTAssertNil(sut.errorMessage)
    }

    // MARK: - fetchHistory

    func testFetchHistoryPopulatesHistory() async {
        repository.stubHistory = [
            HistoryEntry(id: "h1", medicineId: "1", user: "u", action: "Added", details: "x")
        ]
        await sut.fetchHistory(for: medicine("1"))
        XCTAssertEqual(repository.historyRequestedIds, ["1"])
        XCTAssertEqual(sut.history.map(\.id), ["h1"])
    }

    func testFetchHistoryIgnoresMedicineWithoutId() async {
        await sut.fetchHistory(for: Medicine(name: "x", stock: 1, aisle: "A"))
        XCTAssertTrue(repository.historyRequestedIds.isEmpty)
    }

    func testFetchHistorySurfacesRepositoryError() async {
        repository.errorToThrow = TestError.boom
        await sut.fetchHistory(for: medicine("1"))
        XCTAssertEqual(sut.errorMessage, TestError.boom.localizedDescription)
    }

    // MARK: - stopListening

    func testStopListeningCancelsTokensAndAllowsReRegistration() {
        sut.fetchMedicines()
        sut.stopListening()
        XCTAssertEqual(repository.cancelledTokenCount, 1)

        sut.fetchMedicines()
        XCTAssertEqual(repository.observeAllCallCount, 2)
    }

    // MARK: - isNearEnd

    func testIsNearEndWithinThresholdIsTrue() {
        let items = (0..<20).map { medicine("\($0)") }
        XCTAssertTrue(sut.isNearEnd(of: items, item: items[16]))
    }

    func testIsNearEndFarFromEndIsFalse() {
        let items = (0..<20).map { medicine("\($0)") }
        XCTAssertFalse(sut.isNearEnd(of: items, item: items[3]))
    }

    func testIsNearEndUnknownItemIsFalse() {
        let items = (0..<20).map { medicine("\($0)") }
        XCTAssertFalse(sut.isNearEnd(of: items, item: medicine("999")))
    }

    func testIsNearEndShortListIsAlwaysTrue() {
        let items = [medicine("0"), medicine("1")]
        XCTAssertTrue(sut.isNearEnd(of: items, item: items[0]))
    }
}
