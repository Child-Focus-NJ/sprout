require 'rspec/expectations'
World(RSpec::Matchers)

require "cucumber/rails"
require 'warden/test/helpers'

require 'factory_bot_rails'
World(FactoryBot::Syntax::Methods)

require_relative "helpers"


Warden.test_mode!
World(Warden::Test::Helpers)
