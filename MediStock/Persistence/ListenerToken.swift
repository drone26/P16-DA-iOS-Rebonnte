//
//  ListenerToken.swift
//  MediStock
//
//  Created by Mathieu Arrio on 2026/08/30.
//

import Foundation

/// Opaque handle to a live data subscription. Lets the ViewModels tear a listener
/// down without depending on Firestore's `ListenerRegistration` type directly, so
/// they can be driven by an in-memory mock in tests.
protocol ListenerToken: AnyObject {
    func cancel()
}

/// `ListenerToken` backed by an arbitrary teardown closure. The Firestore
/// repository wraps `ListenerRegistration.remove`; mocks record the cancellation.
final class ClosureListenerToken: ListenerToken {
    private var onCancel: (() -> Void)?

    init(_ onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        onCancel?()
        onCancel = nil
    }
}
