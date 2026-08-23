//
//  MedicineDetailView.swift
//  MediStock
//
//  Created by Mathieu Arrio on 2026/08/18.
//

import SwiftUI

struct MedicineDetailView: View {
    @State var medicine: Medicine
    let viewModel: MedicineStockViewModel
    @Environment(SessionStore.self) var session

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Title
                Text(medicine.name)
                    .font(.largeTitle)
                    .foregroundColor(Color("PrimaryText"))
                    .padding(.top, 20)

                // Medicine Name
                medicineNameSection

                // Medicine Stock
                medicineStockSection

                // Medicine Aisle
                medicineAisleSection

                // History Section
                historySection
            }
            .padding(.vertical)
        }
        .navigationBarTitle("Medicine Details", displayMode: .inline)
        .onAppear {
            viewModel.fetchHistory(for: medicine)
        }
        .onChange(of: medicine) { _, newMedicine in
            viewModel.updateMedicine(newMedicine, user: session.session?.uid ?? "")
        }
    }
}

extension MedicineDetailView {
    private func commitUpdate() {
        viewModel.updateMedicine(medicine, user: session.session?.uid ?? "")
    }

    private var medicineNameSection: some View {
        LabeledSection(label: "Name") {
            TextField("Name", text: $medicine.name, onCommit: commitUpdate)
                .formFieldStyle()
        }
    }

    private var medicineStockSection: some View {
        LabeledSection(label: "Stock") {
            HStack {
                Button(action: {
                    viewModel.decreaseStock(medicine, user: session.session?.uid ?? "")
                }) {
                    Image(systemName: "minus.circle")
                        .font(.title)
                        .foregroundColor(Color("NegativeColor"))
                }
                TextField("Stock", value: $medicine.stock, formatter: NumberFormatter(), onCommit: commitUpdate)
                    .formFieldStyle()
                    .keyboardType(.numberPad)
                    .frame(width: 100)
                Button(action: {
                    viewModel.increaseStock(medicine, user: session.session?.uid ?? "")
                }) {
                    Image(systemName: "plus.circle")
                        .font(.title)
                        .foregroundColor(Color("PositiveColor"))
                }
            }
        }
    }

    private var medicineAisleSection: some View {
        LabeledSection(label: "Aisle") {
            TextField("Aisle", text: $medicine.aisle, onCommit: commitUpdate)
                .formFieldStyle()
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading) {
            Text("History")
                .sectionTitleStyle()
                .padding(.top, 20)
            ForEach(viewModel.history.filter { $0.medicineId == medicine.id }, id: \.id) { entry in
                HistoryEntryRow(entry: entry)
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    let sampleMedicine = Medicine(name: "Sample", stock: 10, aisle: "Aisle 1")
    let sampleViewModel = MedicineStockViewModel()
    MedicineDetailView(medicine: sampleMedicine, viewModel: sampleViewModel)
        .environment(SessionStore())
}

#Preview("Dark Mode") {
    let sampleMedicine = Medicine(name: "Sample", stock: 10, aisle: "Aisle 1")
    let sampleViewModel = MedicineStockViewModel()
    MedicineDetailView(medicine: sampleMedicine, viewModel: sampleViewModel)
        .environment(SessionStore())
        .preferredColorScheme(.dark)
}
