# frozen_string_literal: true

require "rails_helper"



RSpec.describe "Information Sessions", type: :request do
  let(:user) { create(:user) }
  let(:information_session) { create(:information_session) }

  before { login_as(user, scope: :user) }

  describe "GET /information_sessions" do
    it "returns a successful response" do
      get information_sessions_path
      expect(response).to be_successful
    end

    it "includes the information session in the list" do
      information_session
      get information_sessions_path
      expect(response.body).to include(information_session.name)
    end

    context "with date filters" do
      it "filters by start_date" do
        information_session
        get information_sessions_path, params: { start_date: 1.week.ago.strftime("%m/%d/%y") }
        expect(response).to be_successful
      end

      it "filters by end_date" do
        information_session
        get information_sessions_path, params: { end_date: 1.month.from_now.strftime("%m/%d/%y") }
        expect(response).to be_successful
      end
    end

    context "with upcoming/past filter" do
      it "filters upcoming sessions" do
        get information_sessions_path, params: { upcoming_past: "Upcoming" }
        expect(response).to be_successful
      end

      it "filters past sessions" do
        get information_sessions_path, params: { upcoming_past: "Past" }
        expect(response).to be_successful
      end
    end

    context "with location filter" do
      it "filters by location" do
        get information_sessions_path, params: { location: "415 Hamburg Turnpike" }
        expect(response).to be_successful
      end
    end
  end

  describe "GET /information_sessions/new" do
    it "returns a successful response" do
      get new_information_session_path
      expect(response).to be_successful
    end
  end

  describe "POST /information_sessions" do
    context "with valid params" do
      let(:valid_params) do
        {
          information_session: {
            name: "Spring Info Session",
            scheduled_at: 1.week.from_now.strftime("%Y-%m-%dT%H:%M"),
            location: "415 Hamburg Turnpike",
            capacity: 10
          }
        }
      end

      it "creates a new information session" do
        expect do
          post information_sessions_path, params: valid_params
        end.to change(InformationSession, :count).by(1)
      end

      it "redirects to the index" do
        post information_sessions_path, params: valid_params
        expect(response).to redirect_to(information_sessions_path)
      end

      it "sets the flash notice" do
        post information_sessions_path, params: valid_params
        expect(flash[:notice]).to eq("Information session was successfully created.")
      end

      it "assigns created_by_user to the current user" do
        post information_sessions_path, params: valid_params
        expect(InformationSession.last.created_by_user).to eq(user)
      end
    end

    context "with invalid params" do
      let(:invalid_params) do
        {
          information_session: {
            name: "Bad Session",
            scheduled_at: nil,
            location: "415 Hamburg Turnpike",
            capacity: 10
          }
        }
      end

      it "does not create a session" do
        expect do
          post information_sessions_path, params: invalid_params
        end.not_to change(InformationSession, :count)
      end

      it "renders the new template" do
        post information_sessions_path, params: invalid_params
        expect(response).to be_unprocessable
      end
    end

    context "with a Zoom session" do
      let(:zoom_params) do
        {
          information_session: {
            name: "Virtual Session",
            scheduled_at: 1.week.from_now.strftime("%Y-%m-%dT%H:%M"),
            location: "Zoom",
            zoom_link: "https://zoom.us/j/123456",
            capacity: 10
          }
        }
      end

      it "creates a virtual session with a zoom link" do
        post information_sessions_path, params: zoom_params
        session = InformationSession.last
        expect(session.zoom_link).to eq("https://zoom.us/j/123456")
        expect(session.session_type).to eq("virtual")
      end
    end
  end

  describe "GET /information_sessions/:id/edit" do
    it "returns a successful response" do
      get edit_information_session_path(information_session)
      expect(response).to be_successful
    end
  end

  describe "PATCH /information_sessions/:id" do
    context "with valid params" do
      it "updates the session" do
        patch information_session_path(information_session), params: {
          information_session: { name: "Updated Name" }
        }
        expect(information_session.reload.name).to eq("Updated Name")
      end

      it "redirects to the edit page" do
        patch information_session_path(information_session), params: {
          information_session: { name: "Updated Name" }
        }
        expect(response).to redirect_to(edit_information_session_path(information_session))
      end
    end

    context "with invalid params" do
      it "renders the edit template" do
        patch information_session_path(information_session), params: {
          information_session: { location: "Invalid Location" }
        }
        expect(response).to be_unprocessable
      end
    end
  end

  describe "DELETE /information_sessions/:id" do
    it "destroys the session" do
      information_session
      expect do
        delete information_session_path(information_session)
      end.to change(InformationSession, :count).by(-1)
    end

    it "redirects to the index" do
      delete information_session_path(information_session)
      expect(response).to redirect_to(information_sessions_path)
    end

    it "sets the flash notice" do
      delete information_session_path(information_session)
      expect(flash[:notice]).to eq("Information session was successfully deleted.")
    end
  end

  describe "DELETE /information_sessions/:id/remove_attendee/:volunteer_id" do
    let(:volunteer) { create(:volunteer) }

    before do
      information_session.volunteers << volunteer
    end

    it "removes the volunteer from the session" do
      delete remove_attendee_information_session_path(information_session, volunteer)
      expect(information_session.reload.volunteers).not_to include(volunteer)
    end

    it "redirects to the edit page" do
      delete remove_attendee_information_session_path(information_session, volunteer)
      expect(response).to redirect_to(edit_information_session_path(information_session))
    end

    it "sets a flash notice with the volunteer's name" do
      delete remove_attendee_information_session_path(information_session, volunteer)
      expect(flash[:notice]).to include(volunteer.full_name)
    end
  end
end
