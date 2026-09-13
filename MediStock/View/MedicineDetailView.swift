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
    /// True when the screen is an empty form for creating a medicine rather than
    /// editing an existing one: it saves via `addMedicine` and dismisses on success,
    /// and hides the (not-yet-existing) history.
    private let isNewMedicine: Bool
    let viewModel: MedicineStockViewModel
    @Environment(SessionStore.self) var session
    @Environment(\.dismiss) private var dismiss

    init(medicine: Medicine, viewModel: MedicineStockViewModel) {
        self.init(medicine: medicine, viewModel: viewModel, isNewMedicine: false)
    }

    /// Opens the screen as an empty form for adding a new medicine (used by the "+"
    /// toolbar button).
    init(viewModel: MedicineStockViewModel) {
        self.init(medicine: Medicine(name: "", stock: 0, aisle: ""), viewModel: viewModel, isNewMedicine: true)
    }

    private init(medicine: Medicine, viewModel: MedicineStockViewModel, isNewMedicine: Bool) {
        _medicine = State(initialValue: medicine)
        _savedMedicine = State(initialValue: medicine)
        self.viewModel = viewModel
        self.isNewMedicine = isNewMedicine
    }

    private var hasUnsavedChanges: Bool {
        medicine != savedMedicine
    }

    private var isSaveEnabled: Bool {
        isMedicineValid && (isNewMedicine || hasUnsavedChanges)
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
                Text(isNewMedicine ? "New Medicine" : medicine.name)
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
                if !isNewMedicine {
                    historySection
                }
            }
            .padding(.vertical)
        }
        .navigationBarTitle(isNewMedicine ? "Add Medicine" : "Medicine Details", displayMode: .inline)
        .toolbar {
            if isNewMedicine {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task {
            if !isNewMedicine {
                await viewModel.fetchHistory(for: medicine)
            }
        }
    }
}

extension MedicineDetailView {
    /// Persists every field at once (name, stock, aisle) as a single write with a
    /// single history entry, instead of writing on every keystroke or every +/- tap.
    private func save() async {
        let user = session.session?.identifier ?? ""
        if isNewMedicine {
            await viewModel.addMedicine(medicine, user: user)
            dismiss()
        } else {
            await viewModel.updateMedicine(medicine, user: user)
            savedMedicine = medicine
        }
    }

    private var medicineNameSection: some View {
        LabeledSection(label: "Name") {
            TextField("Name", text: $medicine.name)
                .formFieldStyle()
                .accessibilityHint(isNameValid ? "" : "Name cannot be empty")
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
                .accessibilityLabel("Decrease stock")
                TextField("Stock", value: $medicine.stock, formatter: NumberFormatter())
                    .formFieldStyle()
                    .keyboardType(.numberPad)
                    .frame(minWidth: 60, idealWidth: 100)
                    .accessibilityLabel("Stock quantity")
                    .accessibilityHint(isStockValid ? "" : "Stock cannot be negative")
                Button(action: { medicine.stock += 1 }) {
                    Image(systemName: "plus.circle")
                        .font(.title)
                        .foregroundColor(Color("PositiveColor"))
                }
                .accessibilityLabel("Increase stock")
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
                .accessibilityHint(isAisleValid ? "" : "Aisle cannot be empty")
            if !isAisleValid {
                Text("Aisle cannot be empty")
                    .sectionSubtitleStyle()
                    .foregroundColor(Color("NegativeColor"))
            }
        }
    }

    private var saveButton: some View {
        Button(action: { Task { await save() } }) {
            Text(isNewMedicine ? "Add Medicine" : "Save Changes")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isSaveEnabled ? Color("PositiveButtonBackground") : Color("SecondaryText"))
                .foregroundColor(.white)
                .cornerRadius(10)
        }
        .disabled(!isSaveEnabled)
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

#Preview("New Medicine") {
    NavigationStack {
        MedicineDetailView(viewModel: MedicineStockViewModel())
    }
    .environment(SessionStore())
}
