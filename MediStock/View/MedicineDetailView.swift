//
//  MedicineDetailView.swift
//  MediStock
//
//  Created by Mathieu Arrio on 2026/08/18.
//

import SwiftUI

struct MedicineDetailView: View {
    @State var medicine: Medicine
    /// The last-saved revision, used only to know whether `medicine` has unsaved edits.
    @State private var savedMedicine: Medicine
    let viewModel: MedicineStockViewModel
    @Environment(SessionStore.self) var session

    init(medicine: Medicine, viewModel: MedicineStockViewModel) {
        _medicine = State(initialValue: medicine)
        _savedMedicine = State(initialValue: medicine)
        self.viewModel = viewModel
    }

    private var hasUnsavedChanges: Bool {
        medicine != savedMedicine
    }

    private var isNameValid: Bool {
        viewModel.isValidName(medicine.name)
    }

    private var isStockValid: Bool {
        viewModel.isValidStock(medicine.stock)
    }

    private var isAisleValid: Bool {
        viewModel.isValidAisle(medicine.aisle)
    }

    private var isMedicineValid: Bool {
        isNameValid && isStockValid && isAisleValid
    }

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

                // Save
                saveButton

                // History Section
                historySection
            }
            .padding(.vertical)
        }
        .navigationBarTitle("Medicine Details", displayMode: .inline)
        .onAppear {
            viewModel.fetchHistory(for: medicine)
        }
    }
}

extension MedicineDetailView {
    /// Persists every field at once (name, stock, aisle) as a single Firestore write with a
    /// single history entry, instead of writing on every keystroke or every +/- tap.
    private func save() {
        viewModel.updateMedicine(medicine, user: session.session?.identifier ?? "")
        savedMedicine = medicine
    }

    private var medicineNameSection: some View {
        LabeledSection(label: "Name") {
            TextField("Name", text: $medicine.name)
                .formFieldStyle()
            if !isNameValid {
                Text("Name cannot be empty")
                    .sectionSubtitleStyle()
                    .foregroundColor(Color("NegativeColor"))
            }
        }
    }

    private var medicineStockSection: some View {
        LabeledSection(label: "Stock") {
            HStack {
                Button(action: { medicine.stock -= 1 }) {
                    Image(systemName: "minus.circle")
                        .font(.title)
                        .foregroundColor(Color("NegativeColor"))
                }
                .disabled(!viewModel.isValidStock(medicine.stock - 1))
                TextField("Stock", value: $medicine.stock, formatter: NumberFormatter())
                    .formFieldStyle()
                    .keyboardType(.numberPad)
                    .frame(width: 100)
                Button(action: { medicine.stock += 1 }) {
                    Image(systemName: "plus.circle")
                        .font(.title)
                        .foregroundColor(Color("PositiveColor"))
                }
            }
            if !isStockValid {
                Text("Stock cannot be negative")
                    .sectionSubtitleStyle()
                    .foregroundColor(Color("NegativeColor"))
            }
        }
    }

    private var medicineAisleSection: some View {
        LabeledSection(label: "Aisle") {
            TextField("Aisle", text: $medicine.aisle)
                .formFieldStyle()
            if !isAisleValid {
                Text("Aisle cannot be empty")
                    .sectionSubtitleStyle()
                    .foregroundColor(Color("NegativeColor"))
            }
        }
    }

    private var saveButton: some View {
        Button(action: save) {
            Text("Save Changes")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(hasUnsavedChanges ? Color("PositiveColor") : Color("SecondaryText"))
                .foregroundColor(.white)
                .cornerRadius(10)
        }
        .disabled(!hasUnsavedChanges || !isMedicineValid)
        .padding(.horizontal)
    }

    private var historySection: some View {
        let entries = viewModel.history.filter { $0.medicineId == medicine.id }
        return VStack(alignment: .leading, spacing: 10) {
            Text("History")
                .sectionTitleStyle()
                .padding(.top, 20)
            if entries.isEmpty {
                Text("No history yet")
                    .sectionSubtitleStyle()
            } else {
                ForEach(entries, id: \.id) { entry in
                    HistoryEntryRow(entry: entry)
                }
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
