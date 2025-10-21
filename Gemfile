# Gemfile
source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.2.2'

# Core Rails
gem 'rails', '~> 7.1.3', '>= 7.1.3.2'
gem 'pg', '~> 1.1'
gem 'puma', '~> 6.4'

# API
gem 'rack-cors'
gem 'jwt'
gem 'rack-attack'

# Security
gem 'bcrypt', '~> 3.1.7'

# Testing
gem 'rspec-rails', '~> 6.1'
gem 'factory_bot_rails'
gem 'faker'
gem 'shoulda-matchers'

# Development
gem 'rubocop', require: false
gem 'rubocop-rails', require: false
gem 'rubocop-rspec', require: false
gem 'annotate'

# Monitoring
gem 'lograge'

group :development do
  gem 'listen', '~> 3.3'
end

group :test do
  gem 'simplecov', require: false
  gem 'database_cleaner-active_record'
end

gem 'psych', '~> 4.0'
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]
