//
//  HistoryEntryRow.swift
//  MediStock
//

import SwiftUI

struct HistoryEntryRow: View {
    let entry: HistoryEntry

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.action)
                    .sectionTitleStyle()
                Spacer()
                Text(Self.dateFormatter.string(from: entry.timestamp))
                    .font(.caption)
                    .foregroundColor(Color("SecondaryText"))
            }
            Label(entry.user, systemImage: "person.circle")
                .sectionSubtitleStyle()
            Text(entry.details)
                .font(.body)
                .foregroundColor(Color("PrimaryText"))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("CardBackground"))
        .cornerRadius(10)
        .accessibilityElement(children: .combine)
    }
}
