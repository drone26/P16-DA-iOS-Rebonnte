import SwiftUI

struct ContentView: View {
    @Environment(SessionStore.self) var session

    var body: some View {
        Group {
            if session.session != nil {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .onAppear {
            session.listen()
        }
    }
}

#Preview {
    ContentView()
        .environment(SessionStore())
}
