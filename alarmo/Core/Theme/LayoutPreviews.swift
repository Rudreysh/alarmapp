import SwiftUI

// MARK: - Layout Previews for Responsive Testing

struct LayoutPreviews_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // MARK: - Timer / Pomo Preview
            PomoTimerView(viewModel: TimerViewModel(preferences: AppPreferences()))
                .previewDisplayName("Timer - iPhone 15 Pro")
                .previewDevice(PreviewDevice(rawValue: "iPhone 15 Pro"))
            
            PomoTimerView(viewModel: TimerViewModel(preferences: AppPreferences()))
                .previewDisplayName("Timer - iPhone 13 mini")
                .previewDevice(PreviewDevice(rawValue: "iPhone 13 mini"))
            
            PomoTimerView(viewModel: TimerViewModel(preferences: AppPreferences()))
                .previewDisplayName("Timer - iPhone 15 Pro Max")
                .previewDevice(PreviewDevice(rawValue: "iPhone 15 Pro Max"))
            
            // MARK: - Mission Preview
            // Note: FindColorTilesMissionView requires complex ViewModel setup, skipping for simple layout preview
            // Instead, we can preview components
             
            // MARK: - Settings Preview
             PomoSettingsView(preferences: AppPreferences())
                .previewDisplayName("Settings - iPhone 13 mini")
                .previewDevice(PreviewDevice(rawValue: "iPhone 13 mini"))
        }
    }
}
