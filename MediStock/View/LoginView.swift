//
//  LoginView.swift
//  MediStock
//
//  Created by Mathieu Arrio on 2026/08/18.
//

import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @Environment(SessionStore.self) var session

    var body: some View {
        @Bindable var session = session
        VStack {
            TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            Button(action: {
                session.signIn(email: email, password: password)
            }) {
                Text("Login")
            }
            Button(action: {
                session.signUp(email: email, password: password)
            }) {
                Text("Sign Up")
            }
        }
        .padding()
        .errorAlert($session.errorMessage)
    }
}

#Preview {
    LoginView()
        .environment(SessionStore())
}
