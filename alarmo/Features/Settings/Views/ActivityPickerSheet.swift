import SwiftUI

#if canImport(FamilyControls)
import FamilyControls
#endif

struct ActivityPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = ScreenTimeAuthorizationManager.shared

    #if canImport(FamilyControls)
    @Binding var selection: FamilyActivitySelection
    @State private var draftSelection: FamilyActivitySelection

    init(selection: Binding<FamilyActivitySelection>) {
        self._selection = selection
        self._draftSelection = State(initialValue: selection.wrappedValue)
    }
    #else
    init() {}
    #endif

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Colors.bgPrimary.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 14) {
                    Text("Choose Activities")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    if !authManager.isAuthorized {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Screen Time access required")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)

                            Button {
                                Task { await authManager.requestAuthorization() }
                            } label: {
                                Text("Enable Screen Time Access")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(Colors.cardSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }

                            if let statusMessage = authManager.statusMessage {
                                Text(statusMessage)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Colors.textSecondary)
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    #if canImport(FamilyControls)
                    FamilyActivityPicker(selection: $draftSelection)
                        .background(Colors.bgPrimary)
                    #else
                    Text("Family Controls is not available on this build.")
                        .foregroundColor(Colors.textSecondary)
                        .padding(.horizontal, 16)
                    #endif
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 14) {
                #if canImport(FamilyControls)
                Button {
                    selection = draftSelection
                    dismiss()
                } label: {
                    Text("Save")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
                #endif

                Button {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Colors.cardSurface)
                        .clipShape(Capsule())
                }
            }
            .padding(16)
            .background(Colors.bgPrimary)
        }
        .onAppear {
            authManager.refreshStatus()
        }
    }
}
