# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Application dashboard", type: :request do
  describe "GET /application_dashboard" do
    context "when signed in as an admin" do
      let(:user) { create(:user, role: :admin) }

      before { login_as(user, scope: :user) }

      it "shows volunteers awaiting submission in order" do
        older = create(
          :volunteer,
          first_name: "Older",
          last_name: "Queue",
          email: "older.queue@childfocusnj.org",
          current_funnel_stage: :application_sent,
          application_sent_at: 3.days.ago
        )
        newer = create(
          :volunteer,
          first_name: "Newer",
          last_name: "Queue",
          email: "newer.queue@childfocusnj.org",
          current_funnel_stage: :application_sent,
          application_sent_at: 1.day.ago
        )

        get application_dashboard_path

        expect(response).to have_http_status(:ok)
        body = response.body
        expect(body).to include("Awaiting submission")
        expect(body).to include("Application sent")
        expect(body).to include(older.email)
        expect(body).to include("View profile")
        panel = response.parsed_body.at_css("details#awaiting-submission")
        expect(panel.text.index(older.full_name)).to be < panel.text.index(newer.full_name)
        expect(panel["open"]).to be_nil
        expect(panel.at_css("summary").text.squish).to eq("Awaiting submission 2")
      end

      it "shows the headline numbers" do
        create_list(:volunteer, 2, current_funnel_stage: :inquiry, inquiry_date: Time.current)
        create(:volunteer, current_funnel_stage: :application_sent, application_sent_at: 5.days.ago)
        create(:volunteer, current_funnel_stage: :inactive, inquiry_date: 2.years.ago)
        create(:information_session, scheduled_at: 3.days.from_now)

        get application_dashboard_path

        tile_text = ->(id) { response.parsed_body.at_css("##{id}").text.squish }
        expect(tile_text.call("stat-volunteers")).to include("Volunteers 4", "3 active · 1 inactive")
        expect(tile_text.call("stat-awaiting-submission")).to include("Awaiting submission 1", "Longest wait: 5 days")
        expect(tile_text.call("stat-upcoming-sessions")).to include("Upcoming info sessions 1")
        # 2 with an inquiry date this month + 1 without one, counted by when it was added
        expect(tile_text.call("stat-new-inquiries")).to include("New inquiries 3")
      end

      it "renders the inquiries and stage charts with their data" do
        create(:volunteer, current_funnel_stage: :applied)

        get application_dashboard_path

        expect(response.parsed_body.at_css("#inquiries-by-month-chart")).to be_present
        expect(response.parsed_body.at_css("#volunteers-by-stage-chart")).to be_present
        expect(response.body).to include("Applied (1)", "Inquiry (0)")
      end

      it "shows the conversion funnel and info session attendance" do
        create(:volunteer, inquiry_date: 2.days.ago)
        create(:volunteer, inquiry_date: 2.days.ago, current_funnel_stage: :applied, application_submitted_at: 1.day.ago)
        session = build(:information_session, scheduled_at: 3.days.ago, location: "Zoom",
                                              zoom_link: "https://zoom.us/j/1", session_type: :virtual)
        session.save!(validate: false)
        # Registrants who inquired long ago, so they stay out of the past year's funnel
        %i[attended registered registered registered].each do |status|
          create(:session_registration, information_session: session, status: status,
                                        volunteer: create(:volunteer, inquiry_date: 2.years.ago))
        end

        get application_dashboard_path

        section_text = ->(id) { response.parsed_body.at_css("##{id}").text.squish }
        expect(section_text.call("conversion-funnel")).to include("50% of inquiries applied")
        expect(section_text.call("funnel-step-inquired")).to include("Inquired 2")
        expect(section_text.call("funnel-step-applied")).to include("Applied 1 · 100% of previous step")
        expect(section_text.call("session-attendance")).to include(
          "25% of registrants attended", "1 of 4 checked in", "#{3.days.ago.strftime('%b %-d')} · Virtual 1 of 4 · 25%"
        )
      end

      it "explains when there's nothing to show yet" do
        get application_dashboard_path

        expect(response.body).to include("No inquiries in the past year yet.",
                                         "No registrations for sessions in the past 90 days.")
      end

      it "lists Dashboard before Volunteers in the main navigation" do
        get volunteers_path

        expect(response).to have_http_status(:ok)
        dashboard_index = response.body.index(">Dashboard<")
        volunteers_index = response.body.index(">Volunteers<")
        expect(dashboard_index).to be_present
        expect(volunteers_index).to be_present
        expect(dashboard_index).to be < volunteers_index
      end
    end

    context "when signed in as a non-admin user" do
      let(:user) { create(:user) }

      before { login_as(user, scope: :user) }

      it "is allowed to view the dashboard" do
        get application_dashboard_path

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "New inquiries column" do
    let(:user) { create(:user) }

    before { login_as(user, scope: :user) }

    def cards
      response.parsed_body.css("#new-inquiries .new-inquiry-card")
    end

    it "shows volunteers added since the staff member's notices began, newest first, with a profile link and an ×" do
      create(:volunteer, first_name: "Old", last_name: "Inquiry", created_at: user.inquiry_notices_since - 1.day)
      rosa = create(:volunteer, first_name: "Rosa", last_name: "Delgado", created_at: 2.minutes.from_now)
      create(:volunteer, first_name: "Leah", last_name: "Brennan", created_at: 3.minutes.from_now)

      get application_dashboard_path

      expect(cards.map { |card| card.at_css(".new-inquiry-card__name").text }).to eq([ "Leah Brennan", "Rosa Delgado" ])
      expect(response.parsed_body.at_css("#new-inquiries .new-inquiries__count").text).to eq("2")
      expect(cards.last.at_css("a")["href"]).to eq(volunteer_path(rosa))
      expect(cards.last.at_css("form")["action"]).to eq(dismiss_new_inquiry_path(rosa))
      expect(cards.last.at_css("button")["aria-label"]).to eq("Dismiss Rosa Delgado")
    end

    it "keeps the column on the page but empty when there's nothing new" do
      get application_dashboard_path

      expect(response.parsed_body.at_css("#new-inquiries h2").text.squish).to eq("New inquiries")
      expect(cards).to be_empty
      expect(response.parsed_body.at_css("#new-inquiries .new-inquiries__count")).to be_nil
      expect(response.parsed_body.at_css("#new-inquiries form[action='#{clear_new_inquiries_path}']")).to be_nil
    end

    it "clears every card for this staff member only, and later inquiries still show" do
      colleague = create(:user)
      create_list(:volunteer, 16)
      get application_dashboard_path
      expect(response.parsed_body.at_css("#new-inquiries form[action='#{clear_new_inquiries_path}'] button").text).to eq("Clear all")

      post clear_new_inquiries_path

      expect(response).to redirect_to(application_dashboard_path)
      expect(response).to have_http_status(:see_other)
      get application_dashboard_path
      expect(cards).to be_empty

      later = travel(1.minute) { create(:volunteer, first_name: "Later", last_name: "Inquiry") }
      get application_dashboard_path
      expect(cards.map { |card| card.at_css(".new-inquiry-card__name").text }).to eq([ later.full_name ])

      login_as(colleague, scope: :user)
      get application_dashboard_path
      expect(response.parsed_body.at_css("#new-inquiries .new-inquiries__count").text).to eq("17")
    end

    it "labels a volunteer who came back after being inactive" do
      user.update!(inquiry_notices_since: 1.hour.ago)
      create(:volunteer, first_name: "Ana", last_name: "Ruiz", created_at: 1.year.ago, reactivated_at: 1.minute.ago)

      get application_dashboard_path

      expect(cards.first.at_css(".new-inquiry-card__meta").text.squish).to eq("Came back 1 minute ago")
    end

    it "shows the newest 15 and says how many there are in all" do
      volunteers = (1..16).map { |minutes| create(:volunteer, created_at: minutes.minutes.from_now) }

      get application_dashboard_path

      expect(cards.size).to eq(15)
      expect(cards.first.at_css("a")["href"]).to eq(volunteer_path(volunteers.last))
      expect(response.parsed_body.at_css("#new-inquiries .new-inquiries__count").text).to eq("16")
      expect(response.parsed_body.at_css(".new-inquiries__more").text.squish).to eq("Showing the newest 15 of 16.")
    end

    it "hides a dismissed volunteer for this staff member only" do
      colleague = create(:user)
      volunteer = create(:volunteer)

      post dismiss_new_inquiry_path(volunteer)

      expect(response).to redirect_to(application_dashboard_path)
      expect(response).to have_http_status(:see_other)
      get application_dashboard_path
      expect(cards).to be_empty

      login_as(colleague, scope: :user)
      get application_dashboard_path
      expect(cards.size).to eq(1)
    end

    it "handles a second × on the same card or an unknown volunteer without an error" do
      volunteer = create(:volunteer, created_at: 1.minute.from_now)

      [ volunteer.id, volunteer.id, 0 ].each do |volunteer_id|
        post dismiss_new_inquiry_path(volunteer_id: volunteer_id)
        expect(response).to redirect_to(application_dashboard_path)
      end
      expect(user.inquiry_dismissals.count).to eq(1)
    end
  end
end
