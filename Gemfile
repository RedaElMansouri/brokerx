# Gemfile
source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.2.2'

# Core Rails
gem 'pg', '~> 1.1'
gem 'puma', '~> 6.4'
gem 'rails', '~> 7.1.3', '>= 7.1.3.2'

# API
gem 'jwt'
gem 'rack-attack'
gem 'rack-cors'

# HTTP Client for microservices communication
gem 'faraday', '~> 2.7'

# Security
gem 'bcrypt', '~> 3.1.7'

# Testing
gem 'factory_bot_rails'
gem 'faker'
gem 'rspec-rails', '~> 6.1'
gem 'shoulda-matchers'

# Développement
gem 'annotate'

# Monitoring
gem 'lograge'
gem 'redis', '~> 5.2'

group :development do
  gem 'listen', '~> 3.3'
end

group :test do
  gem 'database_cleaner-active_record'
  gem 'simplecov', require: false
end

gem 'psych', '~> 4.0'
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]
