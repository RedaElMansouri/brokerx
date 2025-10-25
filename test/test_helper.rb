ENV['RAILS_ENV'] ||= 'test'

# Start SimpleCov before loading the application
begin
  require 'simplecov'
  SimpleCov.start 'rails' do
    add_filter '/bin/'
    add_filter '/db/'
    add_filter '/config/'

    add_group 'Critical', ['app/application', 'app/infrastructure/web/controllers/api']

    # Enforce targeted coverage on critical components.
    # Start with a realistic baseline and increment over time.
    critical_min_coverage = (ENV['CRITICAL_MIN_COVERAGE'] || '20').to_i
    at_exit do
      SimpleCov.result.format!
      critical = SimpleCov.result.groups['Critical']
      if critical && critical.covered_percent < critical_min_coverage
        puts "\nCoverage gate failed: Critical group covered #{critical.covered_percent.round(2)}% (< #{critical_min_coverage}%)\n"
        exit 1
      end
    end
  end
rescue LoadError
  # simplecov not available
end

require_relative '../config/environment'
require 'rails/test_help'

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors, with: :threads)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
