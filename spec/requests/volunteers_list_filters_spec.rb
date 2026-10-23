# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Volunteers list search and status tabs", type: :request do
  let(:user) { create(:user) }
  let(:bergen) { create(:nj_county, name: "Bergen") }
  let(:essex) { create(:nj_county, name: "Essex") }

  let!(:harry) { create(:volunteer, first_name: "Harry", last_name: "Kane", current_funnel_stage: :inquiry, nj_county: bergen) }
  let!(:hana) { create(:volunteer, first_name: "Hana", last_name: "Kimura", current_funnel_stage: :application_eligible, nj_county: bergen) }
  let!(:sofia) { create(:volunteer, first_name: "Sofia", last_name: "Reyes", current_funnel_stage: :inquiry, nj_county: essex) }

  before { login_as(user, scope: :user) }

  def listed_names
    response.parsed_body.css("#volunteer-list .volunteer-name").map { |node| node.text.strip }
  end

  # Each tab's text, e.g. "Inquiry 2", in the order shown
  def tabs
    response.parsed_body.css("#volunteer-status-tabs a").map { |tab| tab.text.squish }
  end

  def active_tab
    response.parsed_body.at_css("#volunteer-status-tabs a[aria-current='page']").text.squish
  end

  describe "GET /volunteers" do
    it "lists everyone alphabetically on the All tab" do
      get volunteers_path

      expect(listed_names).to eq([ "Hana Kimura", "Harry Kane", "Sofia Reyes" ])
      expect(active_tab).to eq("All 3")
    end

    it "shows a tab for every status with how many volunteers are in it" do
      get volunteers_path

      expect(tabs).to eq([ "All 3", "Inquiry 2", "Application eligible 1", "Application sent 0", "Applied 0", "Inactive 0" ])
    end

    it "colors each status tab like that status's badge" do
      get volunteers_path

      tab_classes = response.parsed_body.css("#volunteer-status-tabs a").to_h { |tab| [ tab.text.squish.sub(/ \d+\z/, ""), tab["class"] ] }
      expect(tab_classes["Inquiry"]).to include("status-badge--inquiry")
      expect(tab_classes["Application eligible"]).to include("status-badge--application-eligible")
      expect(tab_classes["Applied"]).to include("status-badge--applied")
      expect(tab_classes["All"]).to include("volunteer-status-tab--all")
    end

    it "shows only that status when a tab is picked" do
      get volunteers_path, params: { status: "inquiry" }

      expect(listed_names).to eq([ "Harry Kane", "Sofia Reyes" ])
      expect(active_tab).to eq("Inquiry 2")
    end

    it "searches by name, and the tab counts follow the search" do
      get volunteers_path, params: { q: "ha" }

      expect(listed_names).to eq([ "Hana Kimura", "Harry Kane" ])
      expect(tabs.first(3)).to eq([ "All 2", "Inquiry 1", "Application eligible 1" ])
    end

    it "combines the search with the status tab" do
      get volunteers_path, params: { q: "ha", status: "inquiry" }

      expect(listed_names).to eq([ "Harry Kane" ])
    end

    it "keeps the search when switching tabs, and the tab when searching" do
      get volunteers_path, params: { q: "ha", status: "inquiry" }
      page = response.parsed_body

      tab = ->(label) { page.css("#volunteer-status-tabs a").find { |link| link.text.squish.start_with?("#{label} ") } }
      expect(tab.call("Applied")["href"]).to eq(volunteers_path(q: "ha", status: "applied"))
      expect(tab.call("All")["href"]).to eq(volunteers_path(q: "ha"))
      expect(page.at_css("form.volunteer-search input[name='status']")["value"]).to eq("inquiry")
      expect(page.at_css("input#q")["value"]).to eq("ha")
    end

    it "no longer has the filter popup or a county filter" do
      get volunteers_path, params: { county_id: essex.id }

      expect(response.parsed_body.at_css(".volunteer-filter-menu")).to be_nil
      expect(response.body).not_to include("All counties")
      expect(listed_names.size).to eq(3)
    end

    it "still shows the county on each volunteer that has one" do
      get volunteers_path

      expect(response.parsed_body.css("#volunteer-list .volunteer-subtext").map(&:text).join).to include("Bergen County", "Essex County")
    end

    it "ignores an unknown status instead of hiding everyone" do
      get volunteers_path, params: { status: "bogus" }

      expect(listed_names.size).to eq(3)
      expect(active_tab).to eq("All 3")
    end

    it "explains an empty search and offers to clear it" do
      get volunteers_path, params: { q: "nobody", status: "inquiry" }

      expect(listed_names).to be_empty
      expect(response.body).to include("No volunteers match your search.")
      expect(response.parsed_body.at_css(".volunteer-list-empty a")["href"]).to eq(volunteers_path(status: "inquiry"))
    end

    it "explains an empty status tab" do
      get volunteers_path, params: { status: "applied" }

      expect(listed_names).to be_empty
      expect(response.body).to include("No volunteers are at Applied right now.")
    end
  end

  describe "POST /volunteers/bulk_add_note from a tab" do
    it "returns to the same tab and search" do
      post bulk_add_note_volunteers_path, params: {
        volunteer_ids: [ harry.id ],
        note: "Called about the next session",
        status: "inquiry",
        q: "ha"
      }

      expect(response).to redirect_to(volunteers_path(q: "ha", status: "inquiry"))
      expect(harry.reload.notes.last.content).to eq("Called about the next session")
    end

    it "keeps the search when the note is rejected" do
      post bulk_add_note_volunteers_path, params: { volunteer_ids: [ harry.id ], note: "", q: "kane" }

      expect(response).to redirect_to(volunteers_path(q: "kane"))
      expect(flash[:alert]).to eq("Content can't be blank")
    end
  end
end
