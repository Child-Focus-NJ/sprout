# frozen_string_literal: true

require "json"
require "net/http"
require "uri"
require "aws-sdk-secretsmanager"
require_relative "../shared/logger"

# Lambda handler for VMS session refresh.
#
# Authenticates with the VMS website (ASP.NET Forms Auth) and stores
# session cookies in Secrets Manager for use by the VMS CRUD Lambda.
#
# Invoked by:
#   - The VMS CRUD Lambda when it detects a stale session (302 → /Account/LogOn)
#   - An optional EventBridge schedule to keep cookies warm
#   - Rails directly via POST /vms/session/refresh

SECRET_ID = "sprout/vms-session"

def handler(event:, context:)
  Shared::Log.logger.info("vms_session_refresh invoked — request_id=#{context.aws_request_id}")

  client = secrets_client
  secret = fetch_secret(client)

  base_url = secret["base_url"]
  username = secret["username"]
  password = secret["password"]

  # Step 1: GET login page to capture session cookie and optional CSRF token
  login_uri = URI("#{base_url}/Account/LogOn")
  http = build_http(login_uri)

  get_response = http.get(login_uri.request_uri)
  Shared::Log.logger.info("GET /Account/LogOn — status=#{get_response.code}")

  # Capture any cookies from the GET response (ASP.NET_SessionId)
  cookies = extract_cookies(get_response)

  # CSRF token is optional — the VMS site may not use them
  csrf_token = extract_csrf_token(get_response.body)

  # Step 2: POST credentials
  post_uri = URI("#{base_url}/Account/LogOn")
  creds = { "UserName" => username, "Password" => password }
  creds["__RequestVerificationToken"] = csrf_token if csrf_token
  form_data = URI.encode_www_form(creds)

  post_request = Net::HTTP::Post.new(post_uri.request_uri)
  post_request["Content-Type"] = "application/x-www-form-urlencoded"
  post_request["Cookie"] = format_cookies(cookies)

  # Don't follow redirects automatically — we need to capture cookies from the 302
  post_response = http.request(post_request, form_data)
  Shared::Log.logger.info("POST /Account/LogOn — status=#{post_response.code}")

  # Merge cookies from POST response
  cookies.merge!(extract_cookies(post_response))

  # Step 3: Verify .ASPXAUTH cookie is present
  unless cookies[".ASPXAUTH"]
    return error_response(401, "Authentication failed — .ASPXAUTH cookie not present. Check credentials.")
  end

  # Step 4: Write updated cookies to Secrets Manager
  refreshed_at = Time.now.utc.iso8601
  updated_secret = secret.merge(
    "cookies" => {
      "ASP.NET_SessionId" => cookies["ASP.NET_SessionId"],
      ".ASPXAUTH" => cookies[".ASPXAUTH"]
    },
    "refreshed_at" => refreshed_at
  )

  client.put_secret_value(
    secret_id: SECRET_ID,
    secret_string: JSON.generate(updated_secret)
  )

  Shared::Log.logger.info("Session refreshed successfully at #{refreshed_at}")

  # Step 5: Return cookies to caller (so CRUD Lambda can retry immediately)
  {
    statusCode: 200,
    headers: { "Content-Type" => "application/json" },
    body: JSON.generate(
      success: true,
      cookies: updated_secret["cookies"],
      refreshed_at: refreshed_at
    )
  }
rescue StandardError => e
  Shared::Log.logger.error("vms_session_refresh error: #{e.class} — #{e.message}")
  error_response(500, e.message)
end

private

def secrets_client
  options = { region: ENV.fetch("AWS_REGION", "us-east-1") }
  if ENV["AWS_ENDPOINT_URL"]
    options[:endpoint] = ENV["AWS_ENDPOINT_URL"]
    options[:credentials] = Aws::Credentials.new("test", "test")
  end
  Aws::SecretsManager::Client.new(options)
end

def fetch_secret(client)
  resp = client.get_secret_value(secret_id: SECRET_ID)
  JSON.parse(resp.secret_string)
end

def build_http(uri)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = (uri.scheme == "https")
  if ENV.fetch("VMS_SSL_VERIFY", "false") == "false"
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end
  http.open_timeout = 10
  http.read_timeout = 15
  http
end

def extract_csrf_token(html)
  match = html.match(/name="__RequestVerificationToken"[^>]*value="([^"]+)"/)
  match&.[](1)
end

def extract_cookies(response)
  cookies = {}
  Array(response.get_fields("set-cookie")).each do |cookie_str|
    name, value = cookie_str.split(";").first.split("=", 2)
    cookies[name.strip] = value&.strip
  end
  cookies
end

def format_cookies(cookies)
  cookies.map { |k, v| "#{k}=#{v}" }.join("; ")
end

def error_response(status, message)
  {
    statusCode: status,
    headers: { "Content-Type" => "application/json" },
    body: JSON.generate(success: false, error: message)
  }
end
