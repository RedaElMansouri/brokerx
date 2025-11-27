# frozen_string_literal: true

ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

require 'bundler/setup'

# Speed up boot time by caching expensive operations
begin
  require 'bootsnap/setup'
rescue LoadError
  # Bootsnap is optional
end
