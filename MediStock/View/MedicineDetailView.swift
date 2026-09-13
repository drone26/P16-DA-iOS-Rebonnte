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
    private var medicineNameSection: some View {
        VStack(alignment: .leading) {
            Text("Name")
                .font(.headline)
                .foregroundColor(Color("PrimaryText"))
            TextField("Name", text: $medicine.name, onCommit: {
                viewModel.updateMedicine(medicine, user: session.session?.uid ?? "")
            })
            .formFieldStyle()
            .padding(.bottom, 10)
        }
        .padding(.horizontal)
    }

    private var medicineStockSection: some View {
        VStack(alignment: .leading) {
            Text("Stock")
                .font(.headline)
                .foregroundColor(Color("PrimaryText"))
            HStack {
                Button(action: {
                    viewModel.decreaseStock(medicine, user: session.session?.uid ?? "")
                }) {
                    Image(systemName: "minus.circle")
                        .font(.title)
                        .foregroundColor(Color("NegativeColor"))
                }
                TextField("Stock", value: $medicine.stock, formatter: NumberFormatter(), onCommit: {
                    viewModel.updateMedicine(medicine, user: session.session?.uid ?? "")
                })
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
            .padding(.bottom, 10)
        }
        .padding(.horizontal)
    }

    private var medicineAisleSection: some View {
        VStack(alignment: .leading) {
            Text("Aisle")
                .font(.headline)
                .foregroundColor(Color("PrimaryText"))
            TextField("Aisle", text: $medicine.aisle, onCommit: {
                viewModel.updateMedicine(medicine, user: session.session?.uid ?? "")
            })
            .formFieldStyle()
            .padding(.bottom, 10)
        }
        .padding(.horizontal)
    }

    private var historySection: some View {
        VStack(alignment: .leading) {
            Text("History")
                .font(.headline)
                .foregroundColor(Color("PrimaryText"))
                .padding(.top, 20)
            ForEach(viewModel.history.filter { $0.medicineId == medicine.id }, id: \.id) { entry in
                VStack(alignment: .leading, spacing: 5) {
                    Text(entry.action)
                        .font(.headline)
                        .foregroundColor(Color("PrimaryText"))
                    Text("User: \(entry.user)")
                        .font(.subheadline)
                        .foregroundColor(Color("SecondaryText"))
                    Text("Date: \(entry.timestamp.formatted())")
                        .font(.subheadline)
                        .foregroundColor(Color("SecondaryText"))
                    Text("Details: \(entry.details)")
                        .font(.subheadline)
                        .foregroundColor(Color("SecondaryText"))
                }
                .padding()
                .background(Color("CardBackground"))
                .cornerRadius(10)
                .padding(.bottom, 5)
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
