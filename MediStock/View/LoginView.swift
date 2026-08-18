import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @Environment(SessionStore.self) var session

    var body: some View {
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
    }
}

#Preview {
    LoginView()
        .environment(SessionStore())
}
