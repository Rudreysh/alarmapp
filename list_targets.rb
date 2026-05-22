require 'xcodeproj'
project_path = '/Users/rukesh/Documents/projects/alarmo/alarmo/alarmo.xcodeproj'
project = Xcodeproj::Project.open(project_path)
puts "TARGETS:"
puts project.targets.map(&:name)
