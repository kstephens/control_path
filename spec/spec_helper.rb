$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start do
    add_filter '/spec/'
  end
end

require 'control_path'
require 'pry'
require 'pp'
require 'awesome_print'
require 'logger'
require 'stringio'

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.mock_framework = :rspec
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
  config.order = 'random'
end

