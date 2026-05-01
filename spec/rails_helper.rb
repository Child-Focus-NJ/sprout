# frozen_string_literal: true

require "spec_helper"
# Docker Compose sets RAILS_ENV=development on `web`; `||= "test"` would not override, so request
# specs would run as development (allow_browser → 403, wrong database). Always load test for RSpec.
ENV["RAILS_ENV"] = "test"
require_relative "../config/environment"
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"

Dir[Rails.root.join("spec/support/**/*.rb")].sort.each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.fixture_paths = [ "#{::Rails.root}/spec/fixtures" ]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include FactoryBot::Syntax::Methods
  config.include Warden::Test::Helpers, type: :request
  config.include ActiveSupport::Testing::TimeHelpers

  config.before(:suite) { Warden.test_mode! }
  config.after(:each, type: :request) { Warden.test_reset! }
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
