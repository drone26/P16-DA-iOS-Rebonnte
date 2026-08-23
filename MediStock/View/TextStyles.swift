//
//  TextStyles.swift
//  MediStock
//

import SwiftUI

extension View {
    /// Style shared by every section/row title (medicine name, field labels, history action…).
    func sectionTitleStyle() -> some View {
        font(.headline)
            .foregroundColor(Color("PrimaryText"))
    }

    /// Style shared by every secondary/detail line (stock count, history metadata…).
    func sectionSubtitleStyle() -> some View {
        font(.subheadline)
            .foregroundColor(Color("SecondaryText"))
    }
}
