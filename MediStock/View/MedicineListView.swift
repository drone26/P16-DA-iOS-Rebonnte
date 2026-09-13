import SwiftUI

struct MedicineListView: View {
    var aisle: String
    let viewModel: MedicineStockViewModel

    var body: some View {
        List {
            ForEach(viewModel.medicines.filter { $0.aisle == aisle }, id: \.id) { medicine in
                NavigationLink(destination: MedicineDetailView(medicine: medicine, viewModel: viewModel)) {
                    VStack(alignment: .leading) {
                        Text(medicine.name)
                            .font(.headline)
                        Text("Stock: \(medicine.stock)")
                            .font(.subheadline)
                    }
                }
            }
        }
        .navigationBarTitle(aisle)
    }
}

#Preview {
    MedicineListView(aisle: "Aisle 1", viewModel: MedicineStockViewModel())
        .environment(SessionStore())
}
