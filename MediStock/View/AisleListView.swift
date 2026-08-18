//
//  AisleListView.swift
//  MediStock
//
//  Created by Mathieu Arrio on 2026/08/18.
//

import SwiftUI

struct AisleListView: View {
    let viewModel: MedicineStockViewModel

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.aisles, id: \.self) { aisle in
                    NavigationLink(destination: MedicineListView(aisle: aisle, viewModel: viewModel)) {
                        Text(aisle)
                    }
                }
            }
            .navigationBarTitle("Aisles")
            .navigationBarItems(trailing: Button(action: {
                viewModel.addRandomMedicine(user: "test_user") // Remplacez par l'utilisateur actuel
            }) {
                Image(systemName: "plus")
            })
        }
    }
}

#Preview {
    AisleListView(viewModel: MedicineStockViewModel())
}
