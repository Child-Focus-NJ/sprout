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
end
