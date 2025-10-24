# Define top-level namespaces and map directories to them so constants like
# ::Infrastructure::..., ::Domain::..., and ::Application::... resolve with Zeitwerk.

module Infrastructure; end
module Domain; end
module Application; end

Rails.autoloaders.main.push_dir(Rails.root.join('app', 'infrastructure'), namespace: Infrastructure)
Rails.autoloaders.main.push_dir(Rails.root.join('app', 'domain'), namespace: Domain)
Rails.autoloaders.main.push_dir(Rails.root.join('app', 'application'), namespace: Application)
Rails.autoloaders.main.push_dir(Rails.root.join('app', 'infrastructure', 'web', 'controllers'))
