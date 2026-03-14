OmniAuth.config.request_validation_phase = nil  # Disables the CSRF check
OmniAuth.config.silence_get_warning = true
OmniAuth.config.allowed_request_methods = [ :post ]

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
           ENV["GOOGLE_CLIENT_ID"],
           ENV["GOOGLE_CLIENT_SECRET"],
           scope: "email,profile",
           prompt: "select_account"
end

if Rails.env.test?
  OmniAuth.config.test_mode = true
end
