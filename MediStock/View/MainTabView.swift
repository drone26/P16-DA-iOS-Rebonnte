import SwiftUI

struct MainTabView: View {
    @State private var viewModel = MedicineStockViewModel()

    var body: some View {
        TabView {
            AisleListView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "list.dash")
                    Text("Aisles")
                }

            AllMedicinesView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "square.grid.2x2")
                    Text("All Medicines")
                }
        }
        .onAppear {
            viewModel.fetchMedicines()
        }
    }
}

#Preview {
    MainTabView()
        .environment(SessionStore())
}
