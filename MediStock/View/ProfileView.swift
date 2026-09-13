//
//  ProfileView.swift
//  MediStock
//

import SwiftUI

struct ProfileView: View {
    @Environment(SessionStore.self) var session

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                LabeledSection(label: "Email") {
                    Text(session.session?.email ?? "Unknown")
                        .sectionSubtitleStyle()
                }

                Button(action: { session.signOut() }) {
                    Text("Logout")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color("NegativeButtonBackground"))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top)
            .navigationBarTitle("Profile")
        }
    }
}

#Preview {
    ProfileView()
        .environment(SessionStore())
}

#Preview("Dark Mode") {
    ProfileView()
        .environment(SessionStore())
        .preferredColorScheme(.dark)
}
