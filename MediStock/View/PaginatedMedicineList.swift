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
    /// When provided, rows get a swipe-to-delete action (confirmed via an alert) that calls
    /// back into this closure. Left `nil` by callers that don't support deletion.
    var onDelete: ((Medicine) -> Void)? = nil

    @State private var medicineToDelete: Medicine?

    var body: some View {
        List {
            ForEach(medicines, id: \.id) { medicine in
                NavigationLink(value: medicine) {
                    MedicineRow(medicine: medicine)
                }
                .onAppear {
                    onRowAppear(medicine)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: onDelete != nil) {
                    if onDelete != nil {
                        Button(role: .destructive) {
                            medicineToDelete = medicine
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
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
        .alert(
            "Delete \(medicineToDelete?.name ?? "this medicine")?",
            isPresented: Binding(
                get: { medicineToDelete != nil },
                set: { isPresented in if !isPresented { medicineToDelete = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                if let medicineToDelete {
                    onDelete?(medicineToDelete)
                }
                medicineToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                medicineToDelete = nil
            }
        } message: {
            Text("This will permanently remove the medicine and cannot be undone.")
        }
    }
}
