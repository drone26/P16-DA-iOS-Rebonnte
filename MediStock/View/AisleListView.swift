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
                    NavigationLink(value: aisle) {
                        Text(aisle)
                    }
                }
            }
            // Using value-based navigation here (instead of the older
            // NavigationLink(destination:)) keeps this whole stack on a single
            // navigation style end-to-end. Mixing NavigationLink(destination:) with
            // .navigationDestination(for:) declared inside the pushed view (as
            // MedicineListView does for Medicine.self) is a known SwiftUI pitfall that
            // silently breaks the inner navigationDestination — taps on a medicine did
            // nothing.
            .navigationDestination(for: String.self) { aisle in
                MedicineListView(aisle: aisle, viewModel: viewModel)
            }
            .navigationBarTitle("Aisles")
        }
    }
}

#Preview {
    AisleListView(viewModel: MedicineStockViewModel())
}

#Preview("Dark Mode") {
    AisleListView(viewModel: MedicineStockViewModel())
        .preferredColorScheme(.dark)
}
