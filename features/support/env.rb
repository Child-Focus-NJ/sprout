require 'cucumber/rails'
require 'capybara/rails'
require 'rspec/expectations'
require 'warden/test/helpers'
require 'factory_bot_rails'

ENV['RAILS_ENV'] = 'test'
ENV['DATABASE_URL'] = ENV['DATABASE_URL']&.sub('_development', '_test')


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


