# Define top-level namespaces and map directories to them so constants like
# ::Infrastructure::... and ::Domain::... resolve with Zeitwerk.

module Infrastructure; end
module Domain; end

Rails.autoloaders.main.push_dir(Rails.root.join('app', 'infrastructure'), namespace: Infrastructure)
Rails.autoloaders.main.push_dir(Rails.root.join('app', 'domain'), namespace: Domain)
