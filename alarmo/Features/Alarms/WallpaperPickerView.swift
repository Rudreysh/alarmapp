import SwiftUI

struct WallpaperPickerView: View {
    @Binding var selectedId: String

    @Environment(\.dismiss) private var dismiss
    @State private var items: [WallpaperItem] = []
    private let loader = BundleWallpaperCatalogLoader()

    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            VStack(spacing: Spacing.l) {
                HStack {
                    Spacer()
                    Text("Alarm wallpaper")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Colors.textPrimary)
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Colors.textSecondary)
                            .frame(width: 36, height: 36)
                    }
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.l)

                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                        ForEach(items) { item in
                            Button(action: {
                                selectedId = item.id
                            }) {
                                ZStack {
                                    if let image = UIImage(contentsOfFile: item.url.path) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                    } else {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(LinearGradient(colors: [.orange, .yellow], startPoint: .top, endPoint: .bottom))
                                    }
                                    if selectedId == item.id {
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Colors.accentRed, lineWidth: 2)
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(Colors.textPrimary)
                                            .background(Circle().fill(Colors.accentRed))
                                            .offset(x: 32, y: -32)
                                    }
                                }
                                .frame(height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(selectedId == item.id ? Colors.accentRed : Color.clear, lineWidth: 2)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.l)
                    
                    PrimaryButton(title: "Select") {
                        dismiss()
                    }
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, Spacing.l)
                }
            }
        }
        .onAppear {
            items = (try? loader.loadCategories().flatMap(\.items)) ?? []
        }
    }
}
