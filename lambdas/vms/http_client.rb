# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require_relative "../shared/logger"
require_relative "session_manager"

module Vms
  # HTTP client for interacting with the VMS website.
  #
  # - Attaches session cookies to every request
  # - Extracts __RequestVerificationToken from HTML form pages
  # - Handles the two-step pattern: GET page (for CSRF token) → POST form data
  # - Retries once on stale session (invokes refresh Lambda)
  class HttpClient
    CSRF_PATTERN = /name="__RequestVerificationToken"[^>]*value="([^"]+)"/

    def initialize(session_manager)
      @session = session_manager
      @retried = false
    end

    # GET request to VMS. Returns Net::HTTPResponse.
    def get(path, headers: {})
      request(:get, path, headers: headers)
    end

    # POST with form-encoded data (for ASP.NET MVC form submissions).
    # Returns Net::HTTPResponse.
    def post_form(path, form_data, headers: {})
      request(:post_form, path, body: form_data, headers: headers)
    end

    # POST with JSON body (for Kendo grid AJAX requests).
    # Returns Net::HTTPResponse.
    def post_json(path, data, headers: {})
      request(:post_json, path, body: data, headers: headers)
    end

    # Two-step form submission:
    # 1. GET the form page to capture hidden fields and optional CSRF token
    # 2. POST with form data (+ CSRF token if present)
    # Returns the POST response.
    def submit_form(get_path, post_path, form_data)
      # Step 1: GET form page
      get_response = get(get_path)

      # CSRF token is optional — the VMS site may not use them
      csrf_token = extract_csrf_token(get_response.body)
      form_data["__RequestVerificationToken"] = csrf_token if csrf_token

      # Step 2: POST form data
      post_form(post_path, form_data)
    end

    # Extract CSRF token from HTML response body.
    def extract_csrf_token(html)
      match = html.match(CSRF_PATTERN)
      match&.[](1)
    end

    # Extract hidden form fields from HTML (used for delete confirmation pages).
    def extract_hidden_fields(html)
      fields = {}
      html.scan(/<input[^>]*type="hidden"[^>]*>/).each do |input|
        name = input.match(/name="([^"]+)"/)&.[](1)
        value = input.match(/value="([^"]*)"/)&.[](1)
        fields[name] = value if name
      end
      fields
    end

    private

    def request(method, path, body: nil, headers: {})
      uri = URI("#{@session.base_url}#{path}")
      http = build_http(uri)

      req = build_request(method, uri, body, headers)
      req["Cookie"] = format_cookies(@session.cookies)

      response = http.request(req)
      Shared::Log.logger.info("#{method.upcase} #{path} — status=#{response.code}")

      # Handle stale session: retry once after refresh
      if @session.stale_session?(response) && !@retried
        @retried = true
        Shared::Log.logger.info("Stale session detected — refreshing")
        @session.refresh!

        req = build_request(method, uri, body, headers)
        req["Cookie"] = format_cookies(@session.cookies)
        response = http.request(req)
        Shared::Log.logger.info("Retry #{method.upcase} #{path} — status=#{response.code}")

        if @session.stale_session?(response)
          raise "Session still stale after refresh — cannot authenticate with VMS"
        end
      end

      response
    ensure
      @retried = false
    end

    def build_request(method, uri, body, headers)
      case method
      when :get
        req = Net::HTTP::Get.new(uri.request_uri)
      when :post_form
        req = Net::HTTP::Post.new(uri.request_uri)
        req["Content-Type"] = "application/x-www-form-urlencoded"
        req.body = URI.encode_www_form(body) if body
      when :post_json
        req = Net::HTTP::Post.new(uri.request_uri)
        req["Content-Type"] = "application/json"
        req["X-Requested-With"] = "XMLHttpRequest"
        req.body = body.to_json if body
      end

      headers.each { |k, v| req[k] = v }
      req
    end

    def build_http(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      # The legacy VMS site (evintotraining.com) has certificate CRL issues.
      # SSL verification is controlled via environment variable, defaulting to
      # disabled for the VMS host.
      if ENV.fetch("VMS_SSL_VERIFY", "false") == "false"
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      http.open_timeout = 15
      http.read_timeout = 30
      http
    end

    def format_cookies(cookies)
      cookies.map { |k, v| "#{k}=#{v}" }.join("; ")
    end
  end
end
