import SwiftUI

struct TagSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var taskStore: TaskStore
    @Binding var selectedTags: [String] // Stores tag names
    
    @State private var showCreateTagSheet = false
    
    var body: some View {
        NavigationView {
            ZStack {
                TimerGlassBackground()
                
                VStack(spacing: Spacing.m) {
                    
                    // Add new tag button
                    Button(action: { showCreateTagSheet = true }) {
                        Text("+ Add a new tag")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Colors.cardSurface)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.l)
                    
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(taskStore.availableTags) { tag in
                                Button(action: {
                                    toggleTag(tag.name)
                                }) {
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(tag.color)
                                            .frame(width: 12, height: 12)
                                        
                                        Text(tag.name)
                                            .font(.system(size: 16))
                                            .foregroundColor(Colors.textPrimary)
                                        
                                        Spacer()
                                        
                                        if selectedTags.contains(tag.name) {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(TimerPalette.accent)
                                        }
                                    }
                                    .padding()
                                    .background(Colors.cardSurface)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .cornerRadius(16)
                        .padding(.horizontal, Spacing.l)
                    }
                }
            }
            .navigationTitle("Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(TimerPalette.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.headline)
                        .foregroundColor(Colors.textPrimary)
                }
            }
            .sheet(isPresented: $showCreateTagSheet) {
                CreateTagView()
                    .environmentObject(taskStore)
                    .presentationDetents([.height(550)]) // Approximate height from screenshot
            }
        }
    }
    
    private func toggleTag(_ name: String) {
        if selectedTags.contains(name) {
            selectedTags.removeAll(where: { $0 == name })
        } else {
            selectedTags.append(name)
        }
    }
}

struct CreateTagView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var taskStore: TaskStore
    
    @State private var tagName: String = ""
    @State private var selectedColorHex: String = "29b6f6" // Default blue
    
    // Palette based on screenshot
    let colors: [String] = [
        "29b6f6", "42a5f5", "64b5f6", "90caf9", "80deea", "4dd0e1", // Row 1
        "2979ff", "7c4dff", "ea80fc", "304ffe", "ce93d8", "f48fb1", // Row 2
        "9fa8da", "d50000", "e91e63", "8d6e63", "f8bbd0", "5d4037", // Row 3
        "d84315", "827717", "f9a825", "bcaaa4", "ffcc80", "f0da50", // Row 4 (Golds/Browns)
        "ffab91", "e6ee9c", "33691e", "004d40", "1b5e20", "006064", // Row 5 (Greens)
        "80cbc4", "c5e1a5", "dcedc8", "b2dfdb", "01579b", "00838f", // Row 6 (Teals/Blues)
        "009688", "4db6ac", "80deea", "90caf9", "9fa8da"  // Row 7
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                TimerGlassBackground()
                
                VStack(spacing: Spacing.l) {
                    
                    TextField("Tag Name", text: $tagName)
                        .font(.system(size: 16))
                        .foregroundColor(Colors.textPrimary)
                        .padding()
                        .background(Colors.cardSurface)
                        .cornerRadius(12)
                        .padding(.top, Spacing.m)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Colour")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Colors.textSecondary)
                        
                        ScrollView {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 16) {
                                ForEach(colors, id: \.self) { hex in
                                    ColorCircle(hex: hex, isSelected: selectedColorHex == hex) {
                                        selectedColorHex = hex
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .padding()
                    .background(Colors.cardSurface)
                    .cornerRadius(16)
                    
                    Spacer()
                }
                .padding(.horizontal, Spacing.l)
            }
            .navigationTitle("Create tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(TimerPalette.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                         saveTag()
                    }
                    .font(.headline)
                    .foregroundColor(Colors.textPrimary)
                    .disabled(tagName.isEmpty)
                }
            }
        }
    }
    
    private func saveTag() {
        let newTag = Tag(name: tagName, colorHex: selectedColorHex)
        taskStore.addTag(newTag)
        dismiss()
    }
}

struct ColorCircle: View {
    let hex: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 44, height: 44)
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
    }
}
