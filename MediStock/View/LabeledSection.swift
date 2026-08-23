//
//  LabeledSection.swift
//  MediStock
//

import SwiftUI

/// Headline label above arbitrary field content, wrapped in the padding used by every
/// editable field section in `MedicineDetailView` (Name, Stock, Aisle).
struct LabeledSection<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading) {
            Text(label)
                .sectionTitleStyle()
            content
                .padding(.bottom, 10)
        }
        .padding(.horizontal)
    }
}
