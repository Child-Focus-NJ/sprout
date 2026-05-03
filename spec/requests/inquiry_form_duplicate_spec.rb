# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Inquiry form duplicate account prevention", type: :request do
  let(:user) { create(:user) }

  before { login_as(user, scope: :user) }

  around do |example|
    ActionMailer::Base.deliveries.clear
    example.run
    ActionMailer::Base.deliveries.clear
  end

  describe "POST /inquiry_form duplicate email detection (no session context)" do
    # US2: Duplicate email does not create a second volunteer
    context "when a volunteer already exists with the submitted email" do
      before { create(:volunteer, email: "dup@childfocusnj.org") }

      it "does not create a second volunteer" do
        expect do
          post inquiry_form_path, params: {
            first_name: "Jane",
            last_name: "Doe",
            email: "dup@childfocusnj.org",
            phone: "5551234567"
          }
        end.not_to change(Volunteer, :count)
      end

      it "redirects with a duplicate email message" do
        post inquiry_form_path, params: {
          first_name: "Jane",
          last_name: "Doe",
          email: "dup@childfocusnj.org",
          phone: "5551234567"
        }
        expect(response).to redirect_to(new_inquiry_form_path)
        follow_redirect!
        expect(response.body).to include("You&#39;ve already signed up.")
      end

      it "does not send a confirmation email" do
        post inquiry_form_path, params: {
          first_name: "Jane",
          last_name: "Doe",
          email: "dup@childfocusnj.org",
          phone: "5551234567"
        }
        expect(ActionMailer::Base.deliveries).to be_empty
      end

      it "does not create an InquiryFormSubmission" do
        expect do
          post inquiry_form_path, params: {
            first_name: "Jane",
            last_name: "Doe",
            email: "dup@childfocusnj.org",
            phone: "5551234567"
          }
        end.not_to change(InquiryFormSubmission, :count)
      end
    end

    # US2: Normalized email matches an existing volunteer (trim + downcase)
    context "when the submitted email differs only in case and whitespace" do
      before { create(:volunteer, email: "casey@childfocusnj.org") }

      it "does not create a second volunteer when email has uppercase and spaces" do
        expect do
          post inquiry_form_path, params: {
            first_name: "Casey",
            last_name: "Smith",
            email: "  CASEY@childfocusnj.org  ",
            phone: "5559876543"
          }
        end.not_to change(Volunteer, :count)
      end

      it "redirects with a duplicate email message for the normalized email" do
        post inquiry_form_path, params: {
          first_name: "Casey",
          last_name: "Smith",
          email: "  CASEY@childfocusnj.org  ",
          phone: "5559876543"
        }
        expect(response).to redirect_to(new_inquiry_form_path)
        follow_redirect!
        expect(response.body).to include("You&#39;ve already signed up.")
      end

      it "does not create a volunteer when only casing differs" do
        expect do
          post inquiry_form_path, params: {
            first_name: "Casey",
            last_name: "Smith",
            email: "Casey@Childfocusnj.Org",
            phone: "5559876543"
          }
        end.not_to change(Volunteer, :count)
      end
    end
  end
end
