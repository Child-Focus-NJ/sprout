require 'cucumber/rails'
require 'capybara/rails'
require 'warden/test/helpers'
require 'rspec/expectations'
require 'factory_bot_rails'

World(RSpec::Matchers)
World(FactoryBot::Syntax::Methods)
World(Warden::Test::Helpers)


OmniAuth.config.test_mode = true


 Before do
  Warden.test_mode!
 end

 After do
   Warden.test_reset!
   OmniAuth.config.mock_auth[:google_oauth2] = nil

end


