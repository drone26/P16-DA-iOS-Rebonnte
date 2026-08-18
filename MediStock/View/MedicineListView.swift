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
        List {
            ForEach(viewModel.medicinesInAisle, id: \.id) { medicine in
                NavigationLink(value: medicine) {
                    VStack(alignment: .leading) {
                        Text(medicine.name)
                            .font(.headline)
                        Text("Stock: \(medicine.stock)")
                            .font(.subheadline)
                    }
                }
            }
        }
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
