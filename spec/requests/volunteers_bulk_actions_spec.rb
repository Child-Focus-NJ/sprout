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
    include_context "Mailchimp SMS enabled"
    let(:client) { instance_double(Mailchimp::TransactionalClient) }

    before do
      allow(Mailchimp::TransactionalClient).to receive(:new).and_return(client)
      allow(client).to receive(:send_sms) do |to:, message:, consent:|
        { "status" => "sent", "external_id" => "bulk-#{to}", "to" => to }
      end
    end

    it "texts everyone with a phone number and says how many were skipped" do
      expect do
        post bulk_send_sms_volunteers_path, params: { volunteer_ids: [ harry.id, sofia.id, nora.id ], message: "See you Thursday", consent: "onetime" }
      end.to change(Communication.sms, :count).by(2)

      expect(response).to redirect_to(volunteers_path)
      expect(flash[:notice]).to eq("SMS sent to 2 volunteers. Skipped 1 with no phone number: Nora Nophone.")
      expect(nora.communications).to be_empty
    end

    it "sends nothing when nobody selected has a phone number" do
      post bulk_send_sms_volunteers_path, params: { volunteer_ids: [ nora.id ], message: "Hi", consent: "onetime" }

      expect(flash[:alert]).to eq("No SMS sent. Skipped 1 with no phone number: Nora Nophone.")
    end

    it "names the first few skipped volunteers and counts the rest, so the message stays short" do
      no_phones = %w[Amy Bob Cal Dee Eve].map { |first| create(:volunteer, first_name: first, last_name: "None", phone: nil) }

      post bulk_send_sms_volunteers_path, params: { volunteer_ids: [ harry.id, *no_phones.map(&:id) ], message: "Hi", consent: "onetime" }

      expect(flash[:notice]).to eq("SMS sent to 1 volunteer. Skipped 5 with no phone number: Amy None, Bob None, Cal None, and 2 more.")
    end

    it "stops on a blank message instead of trying each volunteer" do
      expect do
        post bulk_send_sms_volunteers_path, params: { volunteer_ids: [ harry.id, sofia.id ], message: " " }
      end.not_to change(Communication, :count)

      expect(flash[:alert]).to match(/blank/i)
    end

    it "returns to the filtered list it was sent from" do
      post bulk_send_sms_volunteers_path, params: { volunteer_ids: [ harry.id ], message: "Hi", consent: "onetime", return_to: "/volunteers?q=kane" }

      expect(response).to redirect_to("/volunteers?q=kane")
    end
    it "requires explicit consent for the group before any send" do
      expect do
        post bulk_send_sms_volunteers_path, params: { volunteer_ids: [ harry.id, sofia.id ], message: "Hello" }
      end.not_to change(Communication, :count)
      expect(flash[:alert]).to include("Select the SMS consent")
      expect(client).not_to have_received(:send_sms)
    end

    it "reports sent, queued, uncertain, and rejected attempts separately" do
      uncertain = create(:volunteer, phone: "2015550103")
      rejected = create(:volunteer, phone: "2015550104")
      allow(client).to receive(:send_sms) do |to:, message:, consent:|
        expect(consent).to eq("onetime")
        raise Mailchimp::TransactionalClient::UncertainDeliveryError if to == "+12015550103"
        status = { "+15553334444" => "queued", "+12015550104" => "rejected" }.fetch(to, "sent")
        { "status" => status, "external_id" => "bulk-#{to}", "to" => to }
      end
      post bulk_send_sms_volunteers_path,
        params: { volunteer_ids: [ harry.id, sofia.id, uncertain.id, rejected.id ], message: "Hello", consent: "onetime" }
      expect(flash[:notice]).to include("SMS sent to 1 volunteer.", "SMS queued by Mailchimp for 1 volunteer.",
        "1 SMS could not be confirmed.", "Check Mailchimp activity before resending.", "1 couldn't be sent.")
      expect(harry.communications.last).to be_sent
      expect(sofia.communications.last).to be_queued
      expect(uncertain.communications.last).to be_pending
      expect(rejected.communications.last).to be_failed
    end
  end

  describe "POST /volunteers/bulk_send_application" do
    include_context "Mailchimp email provider"

    it "sends the application to inquiry and eligible volunteers and skips the rest" do
      sofia.update!(current_funnel_stage: :application_eligible)
      already_sent = create(:volunteer, current_funnel_stage: :application_sent, application_sent_at: 3.days.ago)
      applied = create(:volunteer, current_funnel_stage: :applied)
      inactive = create(:volunteer, current_funnel_stage: :inactive)

      post bulk_send_application_volunteers_path,
           params: { volunteer_ids: [ harry, sofia, already_sent, applied, inactive ].map(&:id) }

      expect(flash[:notice]).to eq("Application sent to 2 volunteers. Skipped 3 who already had one, applied, or are inactive.")
      expect(email_client).to have_received(:send_email).with(hash_including(to: harry.email)).once
      expect(email_client).to have_received(:send_email).with(hash_including(to: sofia.email)).once
      expect(email_client).to have_received(:send_email).twice
      expect(harry.reload).to be_application_sent
      expect(harry.communications.email.where(purpose: "application").last).to be_sent
      expect(sofia.reload.application_sent_at).to be_present
      expect(applied.reload).to be_applied
      expect(applied.communications).to be_empty
      expect(inactive.reload).to be_inactive
    end

    it "reports queued, unconfirmed, and rejected emails and does not mark those volunteers sent" do
      queued = create(:volunteer, first_name: "Quinn", last_name: "Queue")
      rejected = create(:volunteer, first_name: "Rita", last_name: "Reject")
      uncertain = create(:volunteer, first_name: "Uma", last_name: "Unsure")
      allow(email_client).to receive(:send_email) do |to:, subject:, text_body:|
        case to
        when queued.email then { "status" => "queued", "external_id" => "queued-id", "to" => to }
        when rejected.email then { "status" => "rejected", "external_id" => "rejected-id", "to" => to, "reject_reason" => "hard-bounce" }
        when uncertain.email then raise Mailchimp::TransactionalClient::UncertainDeliveryError
        else { "status" => "sent", "external_id" => "sent-id", "to" => to }
        end
      end

      post bulk_send_application_volunteers_path,
           params: { volunteer_ids: [ harry.id, queued.id, rejected.id, uncertain.id ] }

      expect(flash[:notice]).to include(
        "Application sent to 1 volunteer.",
        "Application email queued by Mailchimp for 1 volunteer.",
        "1 application email could not be confirmed. Check Mailchimp activity before resending.",
        "1 couldn't be sent."
      )
      expect(harry.reload).to be_application_sent
      expect(queued.reload.application_sent_at).to be_nil
      expect(rejected.reload).to be_inquiry
      expect(uncertain.reload.application_sent_at).to be_nil
      expect(email_client).to have_received(:send_email).exactly(4).times
    end

    it "sends nothing when the application link is not configured" do
      SystemSetting.set("application_url", "")

      expect do
        post bulk_send_application_volunteers_path, params: { volunteer_ids: [ harry.id ] }
      end.not_to change(Communication, :count)

      expect(flash[:alert]).to include("Set the application link")
      expect(harry.reload).to be_inquiry
      expect(email_client).not_to have_received(:send_email)
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
