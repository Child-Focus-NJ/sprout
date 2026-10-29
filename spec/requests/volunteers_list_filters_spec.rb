# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Volunteers list search and status tabs", type: :request do
  let(:user) { create(:user) }
  let(:passaic) { create(:vicinage, name: "Passaic") }
  let(:union) { create(:vicinage, name: "Union") }

  let!(:harry) { create(:volunteer, first_name: "Harry", last_name: "Kane", current_funnel_stage: :inquiry, vicinage: union) }
  let!(:hana) { create(:volunteer, first_name: "Hana", last_name: "Kimura", current_funnel_stage: :application_eligible, vicinage: union) }
  let!(:sofia) { create(:volunteer, first_name: "Sofia", last_name: "Reyes", current_funnel_stage: :inquiry, vicinage: passaic) }

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

    it "filters by vicinage inside a tab, and the tab counts follow the vicinage" do
      get volunteers_path, params: { status: "inquiry", vicinage_id: union.id }

      expect(listed_names).to eq([ "Harry Kane" ])
      expect(tabs.first(3)).to eq([ "All 2", "Inquiry 1", "Application eligible 1" ])
      expect(response.parsed_body.at_css(".volunteer-filter-chip--vicinage").text).to include("Vicinage: Union")
    end

    it "combines the search, status tab and vicinage" do
      get volunteers_path, params: { q: "ha", status: "inquiry", vicinage_id: passaic.id }

      expect(listed_names).to be_empty
      expect(response.parsed_body.at_css(".volunteer-list-empty a")["href"]).to eq(volunteers_path(status: "inquiry"))
    end

    it "keeps the vicinage when switching tabs or searching" do
      get volunteers_path, params: { q: "ha", status: "inquiry", vicinage_id: union.id }
      page = response.parsed_body

      tab = ->(label) { page.css("#volunteer-status-tabs a").find { |link| link.text.squish.start_with?("#{label} ") } }
      expect(tab.call("Applied")["href"]).to eq(volunteers_path(q: "ha", vicinage_id: union.id, status: "applied"))
      expect(tab.call("All")["href"]).to eq(volunteers_path(q: "ha", vicinage_id: union.id))
      expect(page.at_css("form.volunteer-search input#vicinage_id_#{union.id}[checked]")).to be_present
    end

    it "counts the vicinage on the filter button and links the chip to the list without it" do
      get volunteers_path, params: { q: "ha", status: "inquiry", vicinage_id: union.id }
      page = response.parsed_body

      expect(page.at_css(".volunteer-filter-menu__badge").text.strip).to eq("1")
      expect(page.at_css('a[aria-label="Remove vicinage filter"]')["href"]).to eq(volunteers_path(q: "ha", status: "inquiry"))
    end

    it "has no filter badge or vicinage chip when no vicinage is picked" do
      get volunteers_path, params: { q: "ha", status: "inquiry" }

      expect(response.parsed_body.at_css(".volunteer-filter-menu__badge")).to be_nil
      expect(response.parsed_body.at_css("#volunteer-active-filters")).to be_nil
      expect(response.parsed_body.at_css("input#vicinage_id_all[checked]")).to be_present
    end

    it "still shows the vicinage on each volunteer that has one" do
      get volunteers_path

      expect(response.parsed_body.css("#volunteer-list .volunteer-subtext").map(&:text).join).to include("Passaic", "Union")
    end

    it "ignores an unknown status or vicinage instead of hiding everyone" do
      get volunteers_path, params: { status: "bogus", vicinage_id: "999999" }

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

  describe "Back to volunteers link on a profile" do
    def back_link_href
      response.parsed_body.at_css("a.nav-back")["href"]
    end

    it "returns to the tab, search and vicinage the list was showing" do
      get volunteers_path, params: { q: "ha", status: "inquiry", vicinage_id: union.id }
      get volunteer_path(harry)

      expect(back_link_href).to eq(volunteers_path(q: "ha", status: "inquiry", vicinage_id: union.id))
    end

    it "still returns there after an action on the profile" do
      get volunteers_path, params: { status: "inquiry", vicinage_id: union.id }
      patch update_status_volunteer_path(harry), params: { status: "applied" }
      follow_redirect!

      expect(back_link_href).to eq(volunteers_path(status: "inquiry", vicinage_id: union.id))
    end

    it "goes to the plain list once the unfiltered list has been viewed" do
      get volunteers_path, params: { status: "inquiry" }
      get volunteers_path
      get volunteer_path(harry)

      expect(back_link_href).to eq(volunteers_path)
    end

    it "goes to the plain list when no list has been viewed" do
      get volunteer_path(harry)

      expect(back_link_href).to eq(volunteers_path)
    end

    it "leaves out an unknown status" do
      get volunteers_path, params: { q: "ha", status: "bogus" }
      get volunteer_path(harry)

      expect(back_link_href).to eq(volunteers_path(q: "ha"))
    end
  end

  describe "POST /volunteers/bulk_add_note from a tab" do
    it "returns to the same tab, search and vicinage" do
      post bulk_add_note_volunteers_path, params: {
        volunteer_ids: [ harry.id ],
        note: "Called about the next session",
        status: "inquiry",
        q: "ha",
        vicinage_id: union.id
      }

      expect(response).to redirect_to(volunteers_path(q: "ha", status: "inquiry", vicinage_id: union.id))
      expect(harry.reload.notes.last.content).to eq("Called about the next session")
    end

    it "keeps the search when the note is rejected" do
      post bulk_add_note_volunteers_path, params: { volunteer_ids: [ harry.id ], note: "", q: "kane" }

      expect(response).to redirect_to(volunteers_path(q: "kane"))
      expect(flash[:alert]).to eq("Content can't be blank")
    end
  end
end
