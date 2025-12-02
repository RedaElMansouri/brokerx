# frozen_string_literal: true

namespace :test do
  namespace :integration do
    desc 'Run choreographed saga integration tests (requires microservices running)'
    task :saga do
      puts 'Running Choreographed Saga Integration Tests...'
      puts ''
      
      # Check if services are running
      unless system('curl -s http://localhost:3003/health > /dev/null 2>&1')
        puts 'ERROR: Orders service not running on port 3003'
        puts 'Start services with: docker compose -f docker-compose.microservices.yml up -d'
        exit 1
      end

      unless system('curl -s http://localhost:3002/health > /dev/null 2>&1')
        puts 'ERROR: Portfolios service not running on port 3002'
        puts 'Start services with: docker compose -f docker-compose.microservices.yml up -d'
        exit 1
      end

      unless system('redis-cli -p 6379 ping > /dev/null 2>&1')
        puts 'ERROR: Redis not running on port 6379'
        puts 'Start services with: docker compose -f docker-compose.microservices.yml up -d'
        exit 1
      end

      # Run the tests
      system('ruby test/integration/choreographed_saga_integration_test.rb') || exit(1)
    end

    desc 'Run EventBus unit tests'
    task :eventbus do
      puts 'Running EventBus Unit Tests...'
      system('ruby test/integration/eventbus_unit_test.rb') || exit(1)
    end

    desc 'Run all microservices integration tests'
    task microservices: [:saga] do
      puts ''
      puts 'All microservices integration tests completed!'
    end
  end

  desc 'Run all integration tests (alias for test:integration:microservices)'
  task integration: 'integration:microservices'
end
