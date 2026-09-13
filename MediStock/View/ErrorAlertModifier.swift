//
//  ErrorAlertModifier.swift
//  MediStock
//
//  Created by Mathieu Arrio on 2026/08/18.
//

import SwiftUI

extension View {
    /// Shows an alert whenever `message` becomes non-nil, clearing it back to `nil` on dismiss.
    func errorAlert(_ message: Binding<String?>) -> some View {
        alert(
            "Error",
            isPresented: Binding(
                get: { message.wrappedValue != nil },
                set: { isPresented in
                    if !isPresented { message.wrappedValue = nil }
                }
            ),
            presenting: message.wrappedValue
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { errorMessage in
            Text(errorMessage)
        }
    }
}
