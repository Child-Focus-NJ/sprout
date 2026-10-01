# frozen_string_literal: true

require "rails_helper"
RSpec.describe "Google OAuth sign-in", type: :request do
  def mock_google_oauth(email:, uid: "mock-uid-1", first_name: "Test", last_name: "User")
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
      provider: "google_oauth2",
      uid: uid,
      info: { email: email, first_name: first_name, last_name: last_name }
    })
  end

  after { OmniAuth.config.mock_auth[:google_oauth2] = nil }

  describe "with ALLOW_ALL_DOMAINS at its default (true)" do
    it "auto-provisions and signs in a brand-new user on an allowed domain" do
      mock_google_oauth(email: "newperson@passaiccountycasa.org")

      get "/auth/google_oauth2/callback"

      expect(User.find_by(email: "newperson@passaiccountycasa.org")).to be_present
      expect(response).to redirect_to(application_dashboard_path)
    end

    it "rejects someone on a non-allowed domain" do
      mock_google_oauth(email: "someone@gmail.com")

      get "/auth/google_oauth2/callback"

      expect(User.find_by(email: "someone@gmail.com")).to be_nil
      expect(response).to redirect_to(login_path)
      follow_redirect!
      expect(response.body).to include("not been granted access")
    end
  end

  describe "with ALLOW_ALL_DOMAINS set to false" do
    before { ENV["ALLOW_ALL_DOMAINS"] = "false" }
    after { ENV.delete("ALLOW_ALL_DOMAINS") }

    it "still signs in an already-whitelisted user" do
      create(:user, email: "whitelisted@passaiccountycasa.org", role: :user)
      mock_google_oauth(email: "whitelisted@passaiccountycasa.org")

      get "/auth/google_oauth2/callback"

      expect(response).to redirect_to(application_dashboard_path)
    end

    it "rejects a brand-new user even on an otherwise-allowed domain" do
      mock_google_oauth(email: "newperson@passaiccountycasa.org")

      get "/auth/google_oauth2/callback"

      expect(User.find_by(email: "newperson@passaiccountycasa.org")).to be_nil
      expect(response).to redirect_to(login_path)
      follow_redirect!
      expect(response.body).to include("not been granted access")
    end
  end

  describe "a deactivated user" do
    it "is bounced back to login the moment they land, even with valid Google credentials" do
      create(:user, :inactive, email: "gone@passaiccountycasa.org", google_uid: "existing-uid")
      mock_google_oauth(email: "gone@passaiccountycasa.org", uid: "existing-uid")

      get "/auth/google_oauth2/callback"
      expect(response).to redirect_to(application_dashboard_path)

      follow_redirect!

      expect(response).to redirect_to(login_path)
      follow_redirect!
      expect(response.body).to include("Your account is inactive.")
    end
  end
end
