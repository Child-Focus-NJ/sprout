# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Logout", type: :request do
  let(:user) { create(:user) }

  before { login_as(user, scope: :user) }

  describe "DELETE /logout" do
    it "redirects to the login page" do
      delete logout_path

      expect(response).to redirect_to(login_path)
      follow_redirect!
      expect(response.body).to include("You have been logged out.")
    end

    it "shows a Log out control when signed in" do
      get volunteers_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Log out")
    end
  end
end
