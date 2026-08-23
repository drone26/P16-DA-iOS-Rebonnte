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
                .font(.headline)
                .foregroundColor(Color("PrimaryText"))
            Text("Stock: \(medicine.stock)")
                .font(.subheadline)
                .foregroundColor(Color("SecondaryText"))
        }
    }
}
