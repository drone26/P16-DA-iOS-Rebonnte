//
//  PaginatedMedicineList.swift
//  MediStock
//
//  Created by Mathieu Arrio on 2026/08/18.
//

import SwiftUI

/// List of medicines shared by `AllMedicinesView` and `MedicineListView`: renders each
/// medicine as a `NavigationLink`, calling `onRowAppear` as rows scroll into view so the
/// caller can lazily widen its Firestore query, and showing a spinner row while the next
/// page is loading.
struct PaginatedMedicineList: View {
    let medicines: [Medicine]
    let isLoadingMore: Bool
    let onRowAppear: (Medicine) -> Void

    var body: some View {
        List {
            ForEach(medicines, id: \.id) { medicine in
                NavigationLink(value: medicine) {
                    MedicineRow(medicine: medicine)
                }
                .onAppear {
                    onRowAppear(medicine)
                }
            }

            if isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
        }
    }
}
