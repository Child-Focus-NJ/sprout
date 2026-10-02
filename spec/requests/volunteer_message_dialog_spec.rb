# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Note / SMS popup", type: :request do
  let(:user) { create(:user) }
  let(:with_phone) { create(:volunteer, first_name: "Phoebe", last_name: "Phone", phone: "5551234567") }
  let(:without_phone) { create(:volunteer, first_name: "Nora", last_name: "Nophone", phone: nil) }

  before { login_as(user, scope: :user) }

  def page_html
    response.parsed_body
  end

  describe "volunteer profile" do
    it "opens the popup from Add Note and Send SMS instead of a note box and an SMS page" do
      get volunteer_path(with_phone)

      note_button = page_html.at_css("#actions button[data-message-dialog-open='note']")
      sms_button = page_html.at_css("#actions button[data-message-dialog-open='sms']")
      expect(note_button["aria-label"]).to eq("Add Note")
      expect(sms_button["aria-label"]).to eq("Send SMS")
      expect(note_button.at_css("svg.message-icon")).to be_present
      expect(sms_button["disabled"]).to be_nil
      expect(sms_button["data-note-url"]).to eq(add_note_volunteer_path(with_phone))
      expect(sms_button["data-sms-url"]).to eq(send_sms_volunteer_path(with_phone))

      expect(page_html.at_css("dialog#message-dialog")).to be_present
      expect(page_html.at_css("#add-note-form")).to be_nil
      expect(response.body).not_to include("/sms\"")
    end

    it "greys out Send SMS when the volunteer has no phone number" do
      get volunteer_path(without_phone)

      sms_button = page_html.at_css("#actions button[data-message-dialog-open='sms']")
      expect(sms_button["disabled"]).to be_present
      expect(sms_button["title"]).to eq("Send SMS (no phone number on file)")
      expect(sms_button["data-has-phone"]).to eq("false")
    end

    it "sends the popup back to the page it was opened from" do
      get volunteer_path(with_phone)

      return_fields = page_html.css("dialog#message-dialog input[name='return_to']")
      expect(return_fields.map { |field| field["value"] }).to eq([ volunteer_path(with_phone) ] * 2)
    end

    it "lets the SMS box grow and shows the 320 character limit" do
      get volunteer_path(with_phone)

      sms_box = page_html.at_css("dialog#message-dialog textarea[name='message']")
      expect(sms_box["data-autogrow"]).not_to be_nil
      expect(sms_box["maxlength"]).to eq("320")
      expect(page_html.at_css("dialog#message-dialog textarea[name='note']")["data-autogrow"]).not_to be_nil
    end
  end

  describe "volunteers list" do
    it "gives each row its own Add Note and Send SMS buttons, and keeps the filters for the way back" do
      with_phone
      without_phone

      get volunteers_path(q: "o")

      rows = page_html.css(".volunteer-row")
      expect(rows.size).to eq(2)
      rows.each do |row|
        note_label, sms_label = row.css("button[data-message-dialog-open]").map { |button| button["aria-label"] }
        expect(note_label).to eq("Add Note")
        expect(sms_label).to start_with("Send SMS")
      end
      nora_row = rows.find { |row| row.text.include?("Nora Nophone") }
      expect(nora_row.at_css("button[data-message-dialog-open='sms']")["disabled"]).to be_present

      expect(page_html.css("dialog#message-dialog").size).to eq(1)
      expect(page_html.at_css("dialog#message-dialog input[name='return_to']")["value"]).to eq("/volunteers?q=o")
    end
  end

  describe "contact details" do
    it "doesn't require a phone number to save" do
      get volunteer_path(without_phone)
      expect(page_html.at_css("#volunteer_phone")["required"]).to be_nil

      patch volunteer_path(without_phone), params: { volunteer: { first_name: "Nora", phone: "" } }

      expect(response).to redirect_to(volunteer_path(without_phone))
      expect(without_phone.reload.phone).to be_blank
    end
  end
end
