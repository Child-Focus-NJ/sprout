module GoogleOauthHelper
  def stub_google_oauth(email:, first_name: "Test", last_name: "User", uid: "123456789")
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
      provider: "google_oauth2",
      uid: uid,
      info: {
        email: email,
        first_name: first_name,
        last_name: last_name
      },
      credentials: {
        token: "mock_token",
        expires_at: Time.now + 1.week
      }
    })

    Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:google_oauth2]
  end
end

World(GoogleOauthHelper)
