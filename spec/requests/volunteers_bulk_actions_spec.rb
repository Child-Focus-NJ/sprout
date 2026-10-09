# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Bulk actions on the volunteer list", type: :request do
  let(:user) { create(:user) }
  let!(:harry) { create(:volunteer, first_name: "Harry", last_name: "Kane", phone: "5551112222") }
  let!(:sofia) { create(:volunteer, first_name: "Sofia", last_name: "Reyes", phone: "5553334444") }
  let!(:nora) { create(:volunteer, first_name: "Nora", last_name: "Nophone", phone: nil) }

  before { login_as(user, scope: :user) }

  describe "GET /volunteers" do
    it "replaces the bulk note box with a select all and a hidden toolbar" do
      get volunteers_path

      html = response.parsed_body
      expect(html.at_css("#note")).to be_nil
      expect(response.body).not_to include("Add Note to Selected")
      expect(html.at_css("[data-bulk-select-all]")).to be_present
      expect(html.at_css(".volunteer-select-all").text.squish).to eq("Select all 3")

      toolbar = html.at_css("#bulk-toolbar")
      expect(toolbar["hidden"]).not_to be_nil
      expect(toolbar.css("button").map { |button| button.text.squish }).to eq([ "Add Note", "Send SMS", "Send Application", "Clear" ])
    end

    it "marks which rows can get a text" do
      get volunteers_path

      phones = response.parsed_body.css("[data-bulk-select]").to_h { |box| [ box["value"].to_i, box["data-has-phone"] ] }
      expect(phones).to eq(harry.id => "true", sofia.id => "true", nora.id => "false")
    end

    it "only counts the volunteers in the current search for Select all" do
      get volunteers_path(q: "kane")

      expect(response.parsed_body.at_css(".volunteer-select-all").text.squish).to eq("Select all 1")
    end
  end

  describe "POST /volunteers/bulk_send_sms" do
    it "texts everyone with a phone number and says how many were skipped" do
      expect do
        post bulk_send_sms_volunteers_path, params: { volunteer_ids: [ harry.id, sofia.id, nora.id ], message: "See you Thursday" }
      end.to change(Communication.sms, :count).by(2)

      expect(response).to redirect_to(volunteers_path)
      expect(flash[:notice]).to eq("SMS sent to 2 volunteers. Skipped 1 with no phone number.")
      expect(nora.communications).to be_empty
    end

    it "sends nothing when nobody selected has a phone number" do
      post bulk_send_sms_volunteers_path, params: { volunteer_ids: [ nora.id ], message: "Hi" }

      expect(flash[:alert]).to eq("No SMS sent. Skipped 1 with no phone number.")
    end

    it "stops on a blank message instead of trying each volunteer" do
      expect do
        post bulk_send_sms_volunteers_path, params: { volunteer_ids: [ harry.id, sofia.id ], message: " " }
      end.not_to change(Communication, :count)

      expect(flash[:alert]).to match(/blank/i)
    end

    it "returns to the filtered list it was sent from" do
      post bulk_send_sms_volunteers_path, params: { volunteer_ids: [ harry.id ], message: "Hi", return_to: "/volunteers?q=kane" }

      expect(response).to redirect_to("/volunteers?q=kane")
    end
  end

  describe "POST /volunteers/bulk_send_application" do
    it "sends the application to inquiry and eligible volunteers and skips the rest" do
      sofia.update!(current_funnel_stage: :application_eligible)
      already_sent = create(:volunteer, current_funnel_stage: :application_sent, application_sent_at: 3.days.ago)
      applied = create(:volunteer, current_funnel_stage: :applied)
      inactive = create(:volunteer, current_funnel_stage: :inactive)

      post bulk_send_application_volunteers_path,
           params: { volunteer_ids: [ harry, sofia, already_sent, applied, inactive ].map(&:id) }

      expect(flash[:notice]).to eq("Application sent to 2 volunteers. Skipped 3 who already had one, applied, or are inactive.")
      expect(harry.reload).to be_application_sent
      expect(sofia.reload.application_sent_at).to be_present
      expect(applied.reload).to be_applied
      expect(inactive.reload).to be_inactive
    end

    it "keeps the list filters on the way back" do
      post bulk_send_application_volunteers_path, params: { volunteer_ids: [ harry.id ], status: "inquiry" }

      expect(response).to redirect_to(volunteers_path(status: "inquiry"))
    end
  end

  describe "with nobody selected" do
    it "asks to select someone first for every bulk action" do
      post bulk_add_note_volunteers_path, params: { note: "Hello" }
      expect(flash[:alert]).to eq("Select at least one volunteer")

      post bulk_send_sms_volunteers_path, params: { message: "Hello" }
      expect(flash[:alert]).to eq("Select at least one volunteer")

      post bulk_send_application_volunteers_path
      expect(flash[:alert]).to eq("Select at least one volunteer")
    end
  end

  it "adds a bulk note from the popup and returns to the list" do
    post bulk_add_note_volunteers_path,
         params: { volunteer_ids: [ harry.id, nora.id ], note: "Called both", return_to: "/volunteers?q=a" }

    expect(response).to redirect_to("/volunteers?q=a")
    expect(flash[:notice]).to eq("Note added to 2 volunteers")
    expect([ harry, nora ].map { |volunteer| volunteer.notes.last.content }).to eq([ "Called both" ] * 2)
  end
end
