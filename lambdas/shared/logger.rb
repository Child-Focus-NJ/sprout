# frozen_string_literal: true

require "json"
require "logger"

module Shared
  module Log
    # Returns a structured JSON logger suitable for CloudWatch ingestion.
    # Each log line is a single JSON object with timestamp, level, and message.
    def self.logger
      @logger ||= begin
        l = Logger.new($stdout)
        l.formatter = proc do |severity, datetime, _progname, msg|
          JSON.generate(
            timestamp: datetime.utc.iso8601(3),
            level: severity,
            message: msg
          ) + "\n"
        end
        l
      end
    end
  end
end
