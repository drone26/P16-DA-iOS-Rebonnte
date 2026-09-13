//
//  AddMedicineToolbarButton.swift
//  MediStock
//

import SwiftUI

extension View {
    /// Trailing "+" toolbar button that adds a random medicine, shared by `AisleListView`
    /// and `AllMedicinesView`. Reads the signed-in user from `SessionStore` so callers don't
    /// each have to plumb it through.
    func addMedicineToolbarButton(viewModel: MedicineStockViewModel) -> some View {
        modifier(AddMedicineToolbarButtonModifier(viewModel: viewModel))
    }
}

private struct AddMedicineToolbarButtonModifier: ViewModifier {
    let viewModel: MedicineStockViewModel
    @Environment(SessionStore.self) private var session

    func body(content: Content) -> some View {
        content.navigationBarItems(trailing: Button(action: {
            viewModel.addRandomMedicine(user: session.session?.uid ?? "")
        }) {
            Image(systemName: "plus")
        })
    }
}
