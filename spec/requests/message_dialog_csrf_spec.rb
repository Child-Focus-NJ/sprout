require "rails_helper"

RSpec.describe "Message dialog CSRF protection", type: :request do
  include_context "Mailchimp SMS enabled"

  let(:user) { create(:user) }
  let!(:volunteer) { create(:volunteer, phone: "2015550123") }
  let!(:other_volunteer) { create(:volunteer, phone: "2015550124") }
  let(:client) { instance_double(Mailchimp::TransactionalClient) }
  let(:bulk_params) do
    { volunteer_ids: [ volunteer.id, other_volunteer.id ], message: "Hello from CASA", consent: "onetime" }
  end

  around do |example|
    previous_protection = ActionController::Base.allow_forgery_protection
    previous_per_form = ActionController::Base.per_form_csrf_tokens
    ActionController::Base.allow_forgery_protection = true
    ActionController::Base.per_form_csrf_tokens = true
    example.run
  ensure
    ActionController::Base.allow_forgery_protection = previous_protection
    ActionController::Base.per_form_csrf_tokens = previous_per_form
  end

  before do
    login_as(user, scope: :user)
    allow(Mailchimp::TransactionalClient).to receive(:new).and_return(client)
    allow(client).to receive(:send_sms) do |to:, **|
      { "status" => "sent", "external_id" => "csrf-test-#{to}", "to" => to }
    end
    get volunteers_path
  end

  def action_token(path, kind:, document: response.parsed_body)
    button = document.at_css("button[data-#{kind}-url='#{path}']")
    button["data-#{kind}-authenticity-token"].tap { |token| expect(token).to be_present }
  end

  it "accepts the bulk SMS action token from the volunteers page" do
    token = action_token(bulk_send_sms_volunteers_path, kind: :sms)

    expect {
      post bulk_send_sms_volunteers_path, params: bulk_params.merge(authenticity_token: token)
    }.to change(Communication.sms, :count).by(2)

    expect(response).to redirect_to(volunteers_path)
    expect(client).to have_received(:send_sms).twice
  end

  [ :list, :profile ].each do |source|
    it "accepts a single SMS action token from the #{source}" do
      get volunteer_path(volunteer) if source == :profile
      token = action_token(send_sms_volunteer_path(volunteer), kind: :sms)

      expect {
        post send_sms_volunteer_path(volunteer), params: { message: "Hello", consent: "onetime", authenticity_token: token }
      }.to change(volunteer.communications.sms, :count).by(1)
      expect(response).to redirect_to(volunteer_path(volunteer))
    end
  end

  it "accepts a single note action token from the shared dialog" do
    token = action_token(add_note_volunteer_path(volunteer), kind: :note)

    expect {
      post add_note_volunteer_path(volunteer), params: { note: "Followed up", authenticity_token: token }
    }.to change(volunteer.notes, :count).by(1)
    expect(response).to redirect_to(volunteer_path(volunteer))
  end

  it "accepts the bulk note action token from the shared dialog" do
    token = action_token(bulk_add_note_volunteers_path, kind: :note)

    expect {
      post bulk_add_note_volunteers_path, params: {
        volunteer_ids: [ volunteer.id, other_volunteer.id ], note: "Followed up", authenticity_token: token
      }
    }.to change(Note, :count).by(2)
    expect(response).to redirect_to(volunteers_path)
  end

  [ nil, "invalid-token" ].each do |token|
    it "rejects a #{token.nil? ? 'missing' : 'malformed'} token before any SMS is sent" do
      expect {
        post bulk_send_sms_volunteers_path, params: bulk_params.merge(authenticity_token: token)
      }.not_to change(Communication, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(client).not_to have_received(:send_sms)
    end
  end

  it "rejects a valid note token used for the SMS endpoint" do
    token = action_token(bulk_add_note_volunteers_path, kind: :note)

    expect {
      post bulk_send_sms_volunteers_path, params: bulk_params.merge(authenticity_token: token)
    }.not_to change(Communication, :count)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(client).not_to have_received(:send_sms)
  end

  it "rejects a single SMS token used for a different volunteer" do
    token = action_token(send_sms_volunteer_path(volunteer), kind: :sms)

    expect {
      post send_sms_volunteer_path(other_volunteer), params: { message: "Hello", consent: "onetime", authenticity_token: token }
    }.not_to change(Communication, :count)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(client).not_to have_received(:send_sms)
  end

  it "rejects a token copied from a different browser session" do
    other_browser = open_session
    login_as(user, scope: :user)
    other_browser.get volunteers_path
    expect(other_browser.response).to have_http_status(:ok)
    token = action_token(bulk_send_sms_volunteers_path, kind: :sms, document: other_browser.response.parsed_body)

    expect {
      post bulk_send_sms_volunteers_path, params: bulk_params.merge(authenticity_token: token)
    }.not_to change(Communication, :count)
    expect(response).to have_http_status(:unprocessable_entity)
    expect(client).not_to have_received(:send_sms)
  end
end
