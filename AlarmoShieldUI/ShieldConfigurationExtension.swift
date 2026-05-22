import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        return ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterialDark,
            backgroundColor: UIColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 1.0),
            icon: UIImage(systemName: "lock.shield.fill"),
            title: ShieldConfiguration.Label(text: "App Locked", color: .white),
            subtitle: ShieldConfiguration.Label(text: "Alarmo is keeping you focused.", color: .lightGray),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Breathe", color: .black),
            primaryButtonBackgroundColor: .white,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Ignore Limit", color: .systemBlue)
        )
    }
    
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        return configuration(shielding: application)
    }
    
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        return ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterialDark,
            backgroundColor: UIColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 1.0),
            icon: UIImage(systemName: "lock.shield.fill"),
            title: ShieldConfiguration.Label(text: "Website Locked", color: .white),
            subtitle: ShieldConfiguration.Label(text: "Alarmo is keeping you focused.", color: .lightGray),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Breathe", color: .black),
            primaryButtonBackgroundColor: .white,
            secondaryButtonLabel: nil
        )
    }
    
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        return configuration(shielding: webDomain)
    }
}
