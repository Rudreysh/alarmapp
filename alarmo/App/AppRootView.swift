import SwiftUI

struct AppRootView: View {
    var body: some View {
        Text("Alarmo")
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
    }
}

#Preview {
    AppRootView()
}
