require 'xcodeproj'
require 'fileutils'

project_path = '/Users/rukesh/Documents/projects/alarmo/alarmo/alarmo.xcodeproj'
project = Xcodeproj::Project.open(project_path)
main_target = project.targets.find { |t| t.name == 'alarmo' }

ext_name = 'AlarmoWidget'
ext_dir = "/Users/rukesh/Documents/projects/alarmo/alarmo/#{ext_name}"
FileUtils.mkdir_p(ext_dir)

# Create Info.plist for widget
plist_path = File.join(ext_dir, 'Info.plist')
File.write(plist_path, <<-PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.widgetkit-extension</string>
    </dict>
</dict>
</plist>
PLIST
)

# Swift file for Widget
swift_path = File.join(ext_dir, 'AlarmoWidgetLiveActivity.swift')
File.write(swift_path, <<-SWIFT
import ActivityKit
import WidgetKit
import SwiftUI

struct PomoAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var timeRemaining: TimeInterval
        var stateString: String
    }
    var focusName: String
}

@main
struct AlarmoWidgetBundle: WidgetBundle {
    var body: some Widget {
        AlarmoWidgetLiveActivity()
    }
}

struct AlarmoWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PomoAttributes.self) { context in
            // Lock screen/banner UI
            VStack {
                Text("Focus: \\(context.attributes.focusName)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("Focus")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Time")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom")
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T")
            } minimal: {
                Text("M")
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}
SWIFT
)

# Add target
ext_target = project.new_target(:app_extension, ext_name, :ios, '16.0')
ext_target.product_name = ext_name

group = project.main_group.find_subpath(File.join(ext_name), true)
group.set_source_tree('<group>')
group.set_path(ext_name)

swift_ref = group.new_reference(swift_path)
plist_ref = group.new_reference(plist_path)

ext_target.add_file_references([swift_ref])

ext_target.build_configurations.each do |config|
  config.build_settings['INFOPLIST_FILE'] = plist_path
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = "ht.alarmo.#{ext_name}"
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  config.build_settings['MARKETING_VERSION'] = '1.0'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
end

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
