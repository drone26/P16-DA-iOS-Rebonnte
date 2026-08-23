//
//  FormFieldStyle.swift
//  MediStock
//

import SwiftUI

extension View {
    /// Fills a text field with an adaptive background so its bounds stay visible in dark
    /// mode, where `RoundedBorderTextFieldStyle`'s border is nearly invisible against a
    /// black background.
    func formFieldStyle() -> some View {
        padding(10)
            .background(Color("CardBackground"))
            .cornerRadius(8)
    }
}
