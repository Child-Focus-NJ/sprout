# frozen_string_literal: true

require "rails_helper"

RSpec.describe "db/seeds.rb" do
  let(:admin_emails) do
    %w[
      sprout@passaiccountycasa.org
      admin@childfocusnj.org
      az2924@nyu.edu
      wr2256@nyu.edu
      sw6002@nyu.edu
      erica@passaiccountycasa.org
      michelle@passaiccountycasa.org
      mike@passaiccountycasa.org
      peter.depasquale@nyu.edu
    ]
  end

  before { allow($stdout).to receive(:puts) }

  def load_seeds
    Rails.application.load_seed
  end

  it "seeds the default admin and the launch admins as active admins" do
    load_seeds

    admin_emails.each do |email|
      user = User.find_by(email: email)
      expect(user).to be_present, "expected #{email} to be seeded"
      expect(user).to be_admin
      expect(user).to be_active
    end
  end

  it "does not restore admin to a seeded admin who was later demoted" do
    create(:user, role: :admin)
    demoted = create(:user, email: "erica@passaiccountycasa.org", first_name: "Erica", last_name: "From Google", role: :user)

    load_seeds

    expect(demoted.reload).not_to be_admin
    expect(demoted.last_name).to eq("From Google")
  end

  it "does not reactivate a seeded admin who was deliberately deactivated" do
    create(:user, role: :admin)
    gone = create(:user, :inactive, email: "mike@passaiccountycasa.org", role: :admin)

    load_seeds

    expect(gone.reload).not_to be_active
  end

  it "registers every feature as admin-only" do
    load_seeds

    expect(Feature.pluck(:key)).to include("system_management", "users", "admin_usage_reports")
    expect(Feature.where(admin_only: false)).to be_empty
  end

  it "can run twice without duplicating anything" do
    load_seeds

    expect { load_seeds }.not_to change { [ User.count, Feature.count, Volunteer.count, InformationSession.count ] }
  end

  context "in production" do
    before { allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("production")) }

    it "seeds the admins but no demo staff, volunteers, or sessions" do
      load_seeds

      expect(User.pluck(:email)).to match_array(admin_emails)
      expect(Volunteer.count).to eq(0)
      expect(InformationSession.count).to eq(0)
      expect(SessionRegistration.count).to eq(0)
    end
  end
end
