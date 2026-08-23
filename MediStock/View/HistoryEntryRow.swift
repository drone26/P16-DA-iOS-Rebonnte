//
//  HistoryEntryRow.swift
//  MediStock
//

import SwiftUI

struct HistoryEntryRow: View {
    let entry: HistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(entry.action)
                .sectionTitleStyle()
            Text("User: \(entry.user)")
                .sectionSubtitleStyle()
            Text("Date: \(entry.timestamp.formatted())")
                .sectionSubtitleStyle()
            Text("Details: \(entry.details)")
                .sectionSubtitleStyle()
        }
        .padding()
        .background(Color("CardBackground"))
        .cornerRadius(10)
        .padding(.bottom, 5)
    }
}
