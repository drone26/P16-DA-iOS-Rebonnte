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

    private var isEmailValid: Bool {
        session.isValidEmail(email)
    }

    private var isPasswordValid: Bool {
        session.isValidPassword(password)
    }

    private var canSubmit: Bool {
        isEmailValid && isPasswordValid
    }

    var body: some View {
        @Bindable var session = session
        VStack {
            TextField("Email", text: $email)
                .formFieldStyle()
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .padding(.horizontal)
            if !email.isEmpty && !isEmailValid {
                Text("Enter a valid email address")
                    .sectionSubtitleStyle()
                    .foregroundColor(Color("NegativeColor"))
            }
            SecureField("Password", text: $password)
                .formFieldStyle()
                .padding(.horizontal)
                .padding(.top)
            if !password.isEmpty && !isPasswordValid {
                Text("Password must be at least 20 characters")
                    .sectionSubtitleStyle()
                    .foregroundColor(Color("NegativeColor"))
            }
            Button(action: {
                session.signIn(email: email, password: password)
            }) {
                Text("Login")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canSubmit ? Color("PositiveColor") : Color("SecondaryText"))
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(!canSubmit)
            .padding(.horizontal)
            .padding(.top)
            Button(action: {
                session.signUp(email: email, password: password)
            }) {
                Text("Sign Up")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canSubmit ? Color("PositiveColor") : Color("SecondaryText"))
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(!canSubmit)
            .padding(.horizontal)
        }
        .padding()
        .errorAlert($session.errorMessage)
    }
}

#Preview {
    LoginView()
        .environment(SessionStore())
}

#Preview("Dark Mode") {
    LoginView()
        .environment(SessionStore())
        .preferredColorScheme(.dark)
}
