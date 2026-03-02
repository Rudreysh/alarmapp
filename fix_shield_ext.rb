require 'xcodeproj'

project_path = '/Users/rukesh/Documents/projects/alarmo/alarmo/alarmo.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'AlarmoShieldUI' }

exit 1 unless target

target.build_configurations.each do |config|
  config.build_settings['PRODUCT_NAME'] = 'AlarmoShieldUI'
end

project.save
puts "Successfully set PRODUCT_NAME"
