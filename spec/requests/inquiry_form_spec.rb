# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Inquiry form submission", type: :request do
  let(:user) { create(:user) }

  before { login_as(user, scope: :user) }

  around do |example|
    ActionMailer::Base.deliveries.clear
    example.run
    ActionMailer::Base.deliveries.clear
  end

  describe "GET /inquiry_form/new" do
    it "renders the inquiry form" do
      get new_inquiry_form_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /inquiry_form (no session context)" do
    let(:valid_params) do
      {
        first_name: "Jane",
        last_name: "Doe",
        email: "jane@childfocusnj.org",
        phone: "5551234567"
      }
    end

    # US1: Successful submission creates inquiry and shows confirmation
    context "with valid params" do
      it "creates an InquiryFormSubmission" do
        expect do
          post inquiry_form_path, params: valid_params
        end.to change(InquiryFormSubmission, :count).by(1)
      end

      it "does not create a Volunteer record (public form flow)" do
        expect do
          post inquiry_form_path, params: valid_params
        end.not_to change(Volunteer, :count)
      end

      it "redirects with a confirmation notice" do
        post inquiry_form_path, params: valid_params
        expect(response).to redirect_to(new_inquiry_form_path)
        follow_redirect!
        expect(response.body).to include("Thanks! Your inquiry has been submitted.")
      end

      it "stores the submission as unprocessed" do
        post inquiry_form_path, params: valid_params
        submission = InquiryFormSubmission.last
        expect(submission.processed).to be false
        expect(submission.source).to eq("public_inquiry_form")
      end

      # US3: Valid submission triggers confirmation email
      it "sends a confirmation email to the submitted address" do
        post inquiry_form_path, params: valid_params
        expect(ActionMailer::Base.deliveries.size).to eq(1)
        expect(ActionMailer::Base.deliveries.last.to).to include("jane@childfocusnj.org")
      end
    end

    # US1: Missing required fields shows validation errors
    context "with missing email" do
      let(:params_missing_email) do
        { first_name: "Jane", last_name: "Doe", email: "", phone: "5551234567" }
      end

      it "re-renders the form with 422" do
        post inquiry_form_path, params: params_missing_email
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "does not create an InquiryFormSubmission" do
        expect do
          post inquiry_form_path, params: params_missing_email
        end.not_to change(InquiryFormSubmission, :count)
      end

      # US3: Invalid submission does not send an email
      it "does not send any email" do
        post inquiry_form_path, params: params_missing_email
        expect(ActionMailer::Base.deliveries).to be_empty
      end
    end

    context "with missing first name" do
      it "re-renders the form with 422" do
        post inquiry_form_path, params: { first_name: "", last_name: "Doe", email: "jane@childfocusnj.org", phone: "5551234567" }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "with an invalid phone number" do
      it "re-renders the form with 422" do
        post inquiry_form_path, params: { first_name: "Jane", last_name: "Doe", email: "jane@childfocusnj.org", phone: "123" }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "with an invalid email format" do
      it "re-renders the form with 422" do
        post inquiry_form_path, params: { first_name: "Jane", last_name: "Doe", email: "not-an-email", phone: "5551234567" }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
