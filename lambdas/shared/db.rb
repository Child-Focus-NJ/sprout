# frozen_string_literal: true

require "pg"

module Shared
  module Db
    @connection = nil

    # Returns a lazy PG connection using DATABASE_URL.
    # Reuses the same connection across invocations within a single
    # Lambda execution environment (warm start).
    def self.connection
      @connection ||= PG.connect(ENV.fetch("DATABASE_URL"))
    end

    # Resets the connection — useful after fork or connection error.
    def self.reset_connection!
      @connection&.close rescue nil
      @connection = nil
    end
  end
end
