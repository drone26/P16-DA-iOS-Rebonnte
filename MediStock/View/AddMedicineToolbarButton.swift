//
//  AddMedicineToolbarButton.swift
//  MediStock
//

import SwiftUI

extension View {
    /// Trailing "+" toolbar button that opens an empty `MedicineDetailView` form for
    /// creating a new medicine. Used by `AllMedicinesView`.
    func addMedicineToolbarButton(viewModel: MedicineStockViewModel) -> some View {
        modifier(AddMedicineToolbarButtonModifier(viewModel: viewModel))
    }
}

private struct AddMedicineToolbarButtonModifier: ViewModifier {
    let viewModel: MedicineStockViewModel
    @State private var isAddingMedicine = false

    func body(content: Content) -> some View {
        content
            .navigationBarItems(trailing: Button(action: {
                isAddingMedicine = true
            }) {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Add medicine")
            .accessibilityHint("Opens a form to enter a new medicine"))
            .sheet(isPresented: $isAddingMedicine) {
                NavigationStack {
                    MedicineDetailView(viewModel: viewModel)
                }
            }
    }
}
