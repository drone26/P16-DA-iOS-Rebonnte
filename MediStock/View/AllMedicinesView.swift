//
//  AllMedicinesView.swift
//  MediStock
//
//  Created by Mathieu Arrio on 2026/08/18.
//

import SwiftUI

struct AllMedicinesView: View {
    let viewModel: MedicineStockViewModel
    @State private var filterText: String = ""
    @State private var sortOption: SortOption = .none

    var body: some View {
        NavigationStack {
            VStack {
                // Filtrage et Tri
                HStack {
                    TextField("Filter by name", text: $filterText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.leading, 10)
                    
                    Spacer()

                    Picker("Sort by", selection: $sortOption) {
                        Text("None").tag(SortOption.none)
                        Text("Name").tag(SortOption.name)
                        Text("Stock").tag(SortOption.stock)
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding(.trailing, 10)
                }
                .padding(.top, 10)
                
                // Liste des Médicaments
                PaginatedMedicineList(
                    medicines: viewModel.filteredMedicines,
                    isLoadingMore: viewModel.isLoadingMoreFilteredMedicines,
                    onRowAppear: { viewModel.loadMoreFilteredMedicinesIfNeeded(currentItem: $0) }
                )
                // Destination is resolved from the value captured in the NavigationStack's
                // path rather than looked up live in `filteredMedicines`, so editing a
                // medicine's name/aisle while a filter is active (which can remove it from
                // `filteredMedicines`) no longer pops the detail view back to the list.
                .navigationDestination(for: Medicine.self) { medicine in
                    MedicineDetailView(medicine: medicine, viewModel: viewModel)
                }
                .navigationBarTitle("All Medicines")
                .navigationBarItems(trailing: Button(action: {
                    viewModel.addRandomMedicine(user: "test_user") // Remplacez par l'utilisateur actuel
                }) {
                    Image(systemName: "plus")
                })
            }
        }
        .onAppear {
            viewModel.fetchFilteredAndSortedMedicines(filterText: filterText, sortOption: sortOption)
        }
        .onChange(of: filterText) {
            viewModel.fetchFilteredAndSortedMedicines(filterText: filterText, sortOption: sortOption)
        }
        .onChange(of: sortOption) {
            viewModel.fetchFilteredAndSortedMedicines(filterText: filterText, sortOption: sortOption)
        }
    }
}

#Preview {
    AllMedicinesView(viewModel: MedicineStockViewModel())
}
