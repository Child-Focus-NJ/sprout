# frozen_string_literal: true

# Must run before Rails loads (via rails_helper). Enable with COVERAGE=true (see user-story-5-refactor-pr.md).
if ENV["COVERAGE"] == "true"
  require "simplecov"
  SimpleCov.start "rails" do
    add_filter "/spec/"
    add_filter "/config/"
    add_filter "/db/"
    add_filter "/vendor/"
    add_filter "/tmp/"
    add_group "Controllers", "app/controllers"
    add_group "Models", "app/models"
    add_group "Mailers", "app/mailers"
    add_group "Helpers", "app/helpers"
    add_group "Jobs", "app/jobs"
  end
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.disable_monkey_patching!
  config.warnings = true

  if config.files_to_run.one?
    config.default_formatter = "doc"
  end

  config.order = :random
  Kernel.srand config.seed
end
