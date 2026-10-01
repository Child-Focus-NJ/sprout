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
        expect(body.index(older.full_name)).to be < body.index(newer.full_name)

        panel = response.parsed_body.at_css("details#awaiting-submission")
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
end
