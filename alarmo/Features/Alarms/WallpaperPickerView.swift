import SwiftUI

struct WallpaperPickerView: View {
    @Binding var selectedId: String

    private let wallpapers: [String] = ["sunrise", "dawn", "amber", "ocean", "sky", "night"]

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            VStack(spacing: Spacing.l) {
                Text("Alarm wallpaper")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Colors.textPrimary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                    ForEach(wallpapers, id: \.self) { id in
                        Button(action: { selectedId = id }) {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(LinearGradient(colors: [.orange, .yellow], startPoint: .top, endPoint: .bottom))
                                .frame(height: 100)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(selectedId == id ? Colors.accentRed : Color.clear, lineWidth: 2)
                                )
                        }
                    }
                }
            }
            .padding(Spacing.l)
        }
    }
}
