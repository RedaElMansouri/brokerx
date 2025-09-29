# Eagerly load domain shared files to avoid NameError when domain entities are parsed
shared_files = [
  Rails.root.join('app', 'domain', 'shared', 'value_object.rb'),
  Rails.root.join('app', 'domain', 'shared', 'entity.rb'),
  Rails.root.join('app', 'domain', 'shared', 'repository.rb')
]

shared_files.each do |path|
  load path.to_s if File.exist?(path)
end

# Optionally you can eager-load other domain files here if needed to avoid
# autoload ordering issues during runtime or in controller manual loads.
