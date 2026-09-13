//
//  MedicineListView.swift
//  MediStock
//
//  Created by Mathieu Arrio on 2026/08/18.
//

import SwiftUI

struct MedicineListView: View {
    var aisle: String
    let viewModel: MedicineStockViewModel

    var body: some View {
        PaginatedMedicineList(
            medicines: viewModel.medicinesInAisle,
            isLoadingMore: viewModel.isLoadingMoreAisleMedicines,
            onRowAppear: { viewModel.loadMoreAisleMedicinesIfNeeded(currentItem: $0) }
        )
        // See AllMedicinesView: resolving the destination from the pushed value (not a
        // live lookup in medicinesInAisle) keeps the detail view up when editing the
        // medicine's aisle removes it from this aisle-filtered list.
        .navigationDestination(for: Medicine.self) { medicine in
            MedicineDetailView(medicine: medicine, viewModel: viewModel)
        }
        .navigationBarTitle(aisle)
        .onAppear {
            viewModel.fetchMedicines(inAisle: aisle)
        }
    }
}

#Preview {
    MedicineListView(aisle: "Aisle 1", viewModel: MedicineStockViewModel())
        .environment(SessionStore())
}

#Preview("Dark Mode") {
    MedicineListView(aisle: "Aisle 1", viewModel: MedicineStockViewModel())
        .environment(SessionStore())
        .preferredColorScheme(.dark)
}
