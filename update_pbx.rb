require 'xcodeproj'

project_path = '/Users/rukesh/Documents/projects/alarmo/alarmo/alarmo.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

sounds_path = '/Users/rukesh/Documents/projects/alarmo/alarmo/HostedAssets/sounds'
existing_ref = target.resources_build_phase.files_references.find { |fr| fr.path && fr.path.include?('sounds') }

if existing_ref
  puts 'Sounds folder already in Copy Bundle Resources!'
else
  puts 'Adding sounds folder reference...'
  # Find or create reference
  file_ref = project.main_group.children.find { |c| c.path == sounds_path }
  if !file_ref
    file_ref = project.main_group.new_reference(sounds_path)
    file_ref.last_known_file_type = 'folder'
  end
  
  target.resources_build_phase.add_file_reference(file_ref, true)
  project.save
  puts 'Successfully added as folder reference and saved!'
end
