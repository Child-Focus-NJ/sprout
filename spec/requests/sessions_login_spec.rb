# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Login", type: :request do
  describe "GET /login" do
    it "renders the login page" do
      get login_path

      expect(response).to have_http_status(:ok)
    end

    it "shows the Sprout name and CASA context" do
      get login_path

      expect(response.body).to include("Sprout")
      expect(response.body).to include("Volunteer Management System for CASA")
    end

    it "shows the Sprout logo" do
      get login_path

      expect(response.body).to include("alt=\"Sprout logo\"")
    end

    it "shows the Google sign-in control" do
      get login_path

      expect(response.body).to include("Sign in with Google")
    end
  end

  describe "GET /auth/google_oauth2/callback" do
    def mock_google_oauth(email:, uid: "mock-uid-1", first_name: "Test", last_name: "User")
      OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
        provider: "google_oauth2",
        uid: uid,
        info: { email: email, first_name: first_name, last_name: last_name }
      })
    end

    after { OmniAuth.config.mock_auth[:google_oauth2] = nil }

    it "records a sign-in log entry for a successful login" do
      mock_google_oauth(email: "newperson@passaiccountycasa.org")

      expect {
        get "/auth/google_oauth2/callback"
      }.to change(SignInLog, :count).by(1)

      user = User.find_by(email: "newperson@passaiccountycasa.org")
      log = SignInLog.last
      expect(log.user).to eq(user)
      expect(log.ip_address).to be_present
    end

    it "does not record a sign-in log entry for a rejected login" do
      mock_google_oauth(email: "someone@gmail.com")

      expect {
        get "/auth/google_oauth2/callback"
      }.not_to change(SignInLog, :count)
    end
  end
end
