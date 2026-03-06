require 'omniauth'

OmniAuth.config.test_mode = true

def stub_google_oauth(email:)
  OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
    provider: 'google_oauth2',
    uid: '12345',
    info: { email: email, name: 'Test User' }
  )
end