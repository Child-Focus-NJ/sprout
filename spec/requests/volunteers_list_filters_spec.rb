# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Volunteers list search and filters", type: :request do
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

  describe "GET /volunteers" do
    it "lists everyone alphabetically when nothing is filtered" do
      get volunteers_path

      expect(listed_names).to eq([ "Hana Kimura", "Harry Kane", "Sofia Reyes" ])
      expect(response.parsed_body.at_css("#volunteer-count")).to be_nil
      expect(response.parsed_body.at_css(".volunteer-filter-menu__badge")).to be_nil
    end

    it "searches by name" do
      get volunteers_path, params: { q: "kane" }

      expect(listed_names).to eq([ "Harry Kane" ])
      expect(response.body).to include("Showing 1 of 3 volunteers")
    end

    it "filters by status" do
      get volunteers_path, params: { status: "inquiry" }

      expect(listed_names).to eq([ "Harry Kane", "Sofia Reyes" ])
      expect(response.body).to include("Status: Inquiry")
    end

    it "filters by county" do
      get volunteers_path, params: { county_id: essex.id }

      expect(listed_names).to eq([ "Sofia Reyes" ])
      expect(response.body).to include("County: Essex")
    end

    it "combines the name search with status and county" do
      get volunteers_path, params: { q: "ha", status: "inquiry", county_id: bergen.id }

      expect(listed_names).to eq([ "Harry Kane" ])
    end

    it "shows the county on each volunteer that has one" do
      get volunteers_path

      expect(response.parsed_body.css("#volunteer-list .volunteer-subtext").map(&:text).join).to include("Bergen County", "Essex County")
    end

    it "counts active filters on the funnel button, not the name search" do
      get volunteers_path, params: { q: "h", status: "inquiry", county_id: bergen.id }

      expect(response.parsed_body.at_css(".volunteer-filter-menu__badge").text.strip).to eq("2")
    end

    it "keeps the current search and filters selected" do
      get volunteers_path, params: { q: "ha", status: "inquiry", county_id: essex.id }
      page = response.parsed_body

      expect(page.at_css("input#q")["value"]).to eq("ha")
      expect(page.at_css("input#status_inquiry[checked]")).to be_present
      expect(page.at_css("input#county_id_#{essex.id}[checked]")).to be_present
      expect(page.at_css("input#status_all[checked]")).to be_nil
    end

    it "links each filter chip to the list without that filter" do
      get volunteers_path, params: { status: "inquiry", county_id: essex.id }
      page = response.parsed_body

      expect(page.at_css('a[aria-label="Remove status filter"]')["href"]).to eq(volunteers_path(county_id: essex.id))
      expect(page.at_css('a[aria-label="Remove county filter"]')["href"]).to eq(volunteers_path(status: "inquiry"))
    end

    it "ignores an unknown status or county instead of hiding everyone" do
      get volunteers_path, params: { status: "bogus", county_id: "999999" }

      expect(listed_names.size).to eq(3)
      expect(response.parsed_body.at_css("#volunteer-count")).to be_nil
    end

    it "shows an empty state when nothing matches" do
      get volunteers_path, params: { q: "nobody" }

      expect(listed_names).to be_empty
      expect(response.body).to include("No volunteers match your search.")
      expect(response.body).not_to include("Add Note to Selected")
    end
  end

  describe "POST /volunteers/bulk_add_note from a filtered list" do
    it "returns to the same filtered list" do
      post bulk_add_note_volunteers_path, params: {
        volunteer_ids: [ harry.id ],
        note: "Called about the next session",
        status: "inquiry",
        county_id: bergen.id
      }

      expect(response).to redirect_to(volunteers_path(status: "inquiry", county_id: bergen.id))
      expect(harry.reload.notes.last.content).to eq("Called about the next session")
    end

    it "keeps the filters when the note is rejected" do
      post bulk_add_note_volunteers_path, params: { volunteer_ids: [ harry.id ], note: "", q: "kane" }

      expect(response).to redirect_to(volunteers_path(q: "kane"))
      expect(flash[:alert]).to eq("Content can't be blank")
    end
  end
end
