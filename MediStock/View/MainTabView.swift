//
//  MainTabView.swift
//  MediStock
//
//  Created by Mathieu Arrio on 2026/08/18.
//

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

            ProfileView()
                .tabItem {
                    Image(systemName: "person.circle")
                    Text("Profile")
                }
        }
        .onAppear {
            viewModel.fetchMedicines()
        }
        .errorAlert($viewModel.errorMessage)
    }
}

#Preview {
    MainTabView()
        .environment(SessionStore())
}

#Preview("Dark Mode") {
    MainTabView()
        .environment(SessionStore())
        .preferredColorScheme(.dark)
}
