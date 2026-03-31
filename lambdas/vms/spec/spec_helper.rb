# frozen_string_literal: true

require "json"
require "net/http"

# Add lambda source to load path
$LOAD_PATH.unshift(File.join(__dir__, ".."))

# Stub the shared logger before any source requires it
module Shared
  module Log
    def self.logger
      @logger ||= Logger.new(File::NULL)
    end
  end
end

require "transformers/field_normalizer"
require "transformers/kendo_response"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.order = :random
  config.shared_context_metadata_behavior = :apply_to_host_groups
end
