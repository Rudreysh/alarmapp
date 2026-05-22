require 'xcodeproj'
require 'fileutils'

project_path = '/Users/rukesh/Documents/projects/alarmo/alarmo/alarmo.xcodeproj'
project = Xcodeproj::Project.open(project_path)
main_target = project.targets.find { |t| t.name == 'alarmo' }

ext_name = 'AlarmoShieldUI'
ext_dir = "/Users/rukesh/Documents/projects/alarmo/alarmo/#{ext_name}"
FileUtils.mkdir_p(ext_dir)

# Create ShieldConfigurationExtension.swift
swift_file_path = File.join(ext_dir, 'ShieldConfigurationExtension.swift')
File.write(swift_file_path, <<-SWIFT
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
SWIFT
)

# Create Info.plist
plist_path = File.join(ext_dir, 'Info.plist')
File.write(plist_path, <<-PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleDisplayName</key>
    <string>Alarmo Shield</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.ManagedSettingsUI.shield-configuration-service</string>
        <key>NSExtensionPrincipalClass</key>
        <string>$(PRODUCT_MODULE_NAME).ShieldConfigurationExtension</string>
    </dict>
</dict>
</plist>
PLIST
)

# Add target to project
ext_target = project.new_target(:app_extension, ext_name, :ios, '16.0')
ext_target.product_name = ext_name

# Add files to group
group = project.main_group.find_subpath(File.join(ext_name), true)
group.set_source_tree('<group>')
group.set_path(ext_name)

swift_ref = group.new_reference(swift_file_path)
plist_ref = group.new_reference(plist_path)

# Build phases
ext_target.add_file_references([swift_ref])

# Configure build settings
ext_target.build_configurations.each do |config|
  config.build_settings['INFOPLIST_FILE'] = plist_path
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = "ht.alarmo.#{ext_name}"
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  config.build_settings['MARKETING_VERSION'] = '1.0'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
end

# Embed extension in main app
# Find or create "Embed App Extensions" copy files phase
embed_phase = main_target.copy_files_build_phases.find { |bp| bp.name == 'Embed App Extensions' }
unless embed_phase
  embed_phase = main_target.new_copy_files_build_phase('Embed App Extensions')
  embed_phase.symbol_dst_subfolder_spec = :plug_ins
end

build_file = embed_phase.add_file_reference(ext_target.product_reference)
build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

main_target.add_dependency(ext_target)

project.save
puts "Successfully added #{ext_name} target!"
