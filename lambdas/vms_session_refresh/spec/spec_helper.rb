# frozen_string_literal: true

require "webmock/rspec"
require "json"
require "net/http"
require "aws-sdk-secretsmanager"

$LOAD_PATH.unshift(File.join(__dir__, ".."))

module Shared
  module Log
    def self.logger
      @logger ||= Logger.new(File::NULL)
    end
  end
end

require "handler"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.order = :random
  WebMock.disable_net_connect!
end
