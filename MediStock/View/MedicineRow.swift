//
//  MedicineRow.swift
//  MediStock
//
//  Created by Mathieu Arrio on 2026/08/18.
//

import SwiftUI

struct MedicineRow: View {
    let medicine: Medicine

    var body: some View {
        VStack(alignment: .leading) {
            Text(medicine.name)
                .sectionTitleStyle()
            Text("Stock: \(medicine.stock)")
                .sectionSubtitleStyle()
        }
        .accessibilityElement(children: .combine)
        // Stable handle for UI tests: `.combine` collapses the name/stock labels into
        // one element, so a plain name lookup no longer matches.
        .accessibilityIdentifier("medicineRow-\(medicine.name)")
    }
}
