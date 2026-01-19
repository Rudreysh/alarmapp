import SwiftUI
import Combine

class PhraseSelectionViewModel: ObservableObject {
    @Published var activeTab: PhraseCategory = .short
    @Published var temporarySelectedIDs: Set<UUID>
    @Published var showCreateSheet: Bool = false
    
    init(initialSelectedIDs: Set<UUID>) {
        self.temporarySelectedIDs = initialSelectedIDs
    }
    
    var filteredPhrases: [Phrase] {
        TypingMissionStore.shared.allPhrases.filter { $0.category == activeTab }
    }
    
    var isAllSelected: Bool {
        let currentTabIDs = filteredPhrases.map { $0.id }
        guard !currentTabIDs.isEmpty else { return false }
        return currentTabIDs.allSatisfy { temporarySelectedIDs.contains($0) }
    }
    
    func toggleSelectAll() {
        let currentTabIDs = filteredPhrases.map { $0.id }
        if isAllSelected {
            currentTabIDs.forEach { temporarySelectedIDs.remove($0) }
        } else {
            currentTabIDs.forEach { temporarySelectedIDs.insert($0) }
        }
    }
    
    func toggleSelection(for id: UUID) {
        if temporarySelectedIDs.contains(id) {
            temporarySelectedIDs.remove(id)
        } else {
            temporarySelectedIDs.insert(id)
        }
    }
}

struct PhraseSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedIDs: Set<UUID>
    @StateObject var viewModel: PhraseSelectionViewModel
    var onConfirm: () -> Void
    
    init(selectedIDs: Binding<Set<UUID>>, onConfirm: @escaping () -> Void) {
        self._selectedIDs = selectedIDs
        self._viewModel = StateObject(wrappedValue: PhraseSelectionViewModel(initialSelectedIDs: selectedIDs.wrappedValue))
        self.onConfirm = onConfirm
    }
    
    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Tabs
                tabBar
                
                // Content
                if viewModel.activeTab == .myPhrases && viewModel.filteredPhrases.isEmpty {
                    emptyMyPhrasesView
                } else {
                    phraseList
                }
            }
        }
        .sheet(isPresented: $viewModel.showCreateSheet) {
            CreatePhraseSheet { newText in
                TypingMissionStore.shared.saveUserPhrase(newText)
                // The store auto-refreshes and selects, but we should update our local state too
                if let last = TypingMissionStore.shared.allPhrases.last {
                    viewModel.temporarySelectedIDs.insert(last.id)
                }
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .foregroundColor(.white)
            
            Spacer()
            
            Text("Select the sentences")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
            
            Button("OK") {
                selectedIDs = viewModel.temporarySelectedIDs
                onConfirm()
                dismiss()
            }
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
    
    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 24) {
                ForEach(PhraseCategory.allCases) { category in
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Text(category.rawValue)
                                .font(.system(size: 14, weight: viewModel.activeTab == category ? .bold : .medium))
                                .foregroundColor(viewModel.activeTab == category ? .white : Colors.textSecondary)
                            
                            let count = TypingMissionStore.shared.allPhrases.filter { $0.category == category && viewModel.temporarySelectedIDs.contains($0.id) }.count
                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(0.15))
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                            }
                        }
                        
                        // Underline
                        Rectangle()
                            .fill(viewModel.activeTab == category ? Color.cyan : Color.clear)
                            .frame(height: 2)
                    }
                    .onTapGesture {
                        withAnimation {
                            viewModel.activeTab = category
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 8)
    }
    
    private var phraseList: some View {
        ScrollView {
            VStack(spacing: 0) {
                // My Phrases "Create new" button
                if viewModel.activeTab == .myPhrases && !viewModel.filteredPhrases.isEmpty {
                    createNewButton.padding(20)
                }
                
                // Select all row
                Button(action: { viewModel.toggleSelectAll() }) {
                    HStack(spacing: 16) {
                        checkbox(isSelected: viewModel.isAllSelected)
                        Text("Select all")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 20)
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                // Phrase rows
                ForEach(viewModel.filteredPhrases) { phrase in
                    let isSelected = viewModel.temporarySelectedIDs.contains(phrase.id)
                    Button(action: { viewModel.toggleSelection(for: phrase.id) }) {
                        HStack(spacing: 16) {
                            checkbox(isSelected: isSelected)
                            Text(phrase.text)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                        .background(isSelected ? Color.white.opacity(0.08) : Color.clear)
                    }
                    Divider().background(Color.white.opacity(0.05))
                        .padding(.leading, 56)
                }
            }
        }
    }
    
    private var emptyMyPhrasesView: some View {
        VStack(spacing: 40) {
            createNewButton.padding(.horizontal, 20)
            
            VStack(spacing: 16) {
                Image(systemName: "book")
                    .font(.system(size: 80))
                    .foregroundColor(Color.white.opacity(0.2))
                
                Text("No My Phrases added yet")
                    .font(.system(size: 16))
                    .foregroundColor(Colors.textSecondary)
            }
            
            Spacer()
        }
        .padding(.top, 40)
    }
    
    private var createNewButton: some View {
        Button(action: { viewModel.showCreateSheet = true }) {
            HStack {
                Image(systemName: "plus")
                Text("Create new")
            }
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    private func checkbox(isSelected: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .stroke(isSelected ? Color.cyan : Color.white.opacity(0.3), lineWidth: 2)
                .frame(width: 22, height: 22)
            
            if isSelected {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.cyan)
                    .frame(width: 22, height: 22)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.black)
            }
        }
    }
}

struct CreatePhraseSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var text: String = ""
    let onSave: (String) -> Void
    
    var body: some View {
        ZStack {
            Colors.bgPrimary.ignoresSafeArea()
            
            VStack(spacing: 24) {
                HStack {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                    Spacer()
                    Text("Create new")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Button("Save") {
                        if !text.isEmpty {
                            onSave(text)
                            dismiss()
                        }
                    }
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(text.isEmpty ? Colors.textTertiary : .white)
                    .disabled(text.isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                TextEditor(text: $text)
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .background(Colors.cardSurface)
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    .frame(height: 200)
                
                Spacer()
            }
        }
    }
}
