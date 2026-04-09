# frozen_string_literal: true

require "json"
require "aws-sdk-secretsmanager"
require "aws-sdk-lambda"
require_relative "../shared/logger"

module Vms
  # Manages VMS session cookies via Secrets Manager.
  #
  # - Reads cached cookies for use by the HTTP client
  # - Detects stale sessions (302 redirect to /Account/LogOn)
  # - Invokes the Session Refresh Lambda when cookies are stale
  # - Caches the secret in memory for warm Lambda starts
  class SessionManager
    SECRET_ID = "sprout/vms-session"
    REFRESH_FUNCTION = "sprout-vms-session-refresh"
    LOGIN_PATH = "/Account/LogOn"

    attr_reader :base_url

    def initialize
      @secret = nil
    end

    # Returns the current session cookies hash.
    # Fetches from Secrets Manager on first call, then caches in memory.
    def cookies
      secret["cookies"] || {}
    end

    def base_url
      secret["base_url"]
    end

    # Returns true if the HTTP response indicates a stale session
    # (302 redirect to the login page).
    def stale_session?(response)
      return false unless response.is_a?(Net::HTTPRedirection)

      location = response["location"] || ""
      location.include?(LOGIN_PATH)
    end

    # Invokes the Session Refresh Lambda synchronously and returns fresh cookies.
    # Clears the cached secret so the next call to #cookies returns fresh values.
    def refresh!
      Shared::Log.logger.info("SessionManager: invoking #{REFRESH_FUNCTION} for session refresh")

      resp = lambda_client.invoke(
        function_name: REFRESH_FUNCTION,
        invocation_type: "RequestResponse",
        payload: JSON.generate({})
      )

      payload = JSON.parse(resp.payload.read)
      body = JSON.parse(payload["body"] || "{}")

      unless body["success"]
        raise "Session refresh failed: #{body["error"]}"
      end

      # Update cached secret with fresh cookies inline — avoids an extra
      # Secrets Manager read when the caller immediately retries.
      fresh_cookies = body["cookies"]
      if @secret
        @secret = @secret.merge("cookies" => fresh_cookies)
      else
        @secret = { "cookies" => fresh_cookies }
      end
      fresh_cookies
    end

    private

    def secret
      @secret ||= fetch_secret
    end

    def fetch_secret
      resp = secrets_client.get_secret_value(secret_id: SECRET_ID)
      JSON.parse(resp.secret_string)
    end

    def secrets_client
      @secrets_client ||= begin
        options = { region: ENV.fetch("AWS_REGION", "us-east-1") }
        if ENV["AWS_ENDPOINT_URL"]
          options[:endpoint] = ENV["AWS_ENDPOINT_URL"]
          options[:credentials] = Aws::Credentials.new("test", "test")
        end
        Aws::SecretsManager::Client.new(options)
      end
    end

    def lambda_client
      @lambda_client ||= begin
        options = { region: ENV.fetch("AWS_REGION", "us-east-1") }
        if ENV["AWS_ENDPOINT_URL"]
          options[:endpoint] = ENV["AWS_ENDPOINT_URL"]
          options[:credentials] = Aws::Credentials.new("test", "test")
        end
        Aws::Lambda::Client.new(options)
      end
    end
  end
end
