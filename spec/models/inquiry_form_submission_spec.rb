# frozen_string_literal: true

require "rails_helper"

RSpec.describe InquiryFormSubmission, type: :model do
  describe "associations" do
    it "associates a county and referral source" do
      county = create(:nj_county)
      source = create(:referral_source)
      submission = create(:inquiry_form_submission, nj_county: county, referral_source: source)

      expect(submission.nj_county).to eq(county)
      expect(submission.referral_source).to eq(source)
    end

    it "can be created without a county or referral source" do
      submission = build(:inquiry_form_submission, nj_county: nil, referral_source: nil)
      expect(submission).to be_valid
    end

    it "associates a preferred session" do
      session = create(:information_session)
      submission = create(:inquiry_form_submission, :for_session_check_in, preferred_session: session)

      expect(submission.preferred_session).to eq(session)
      expect(submission.source).to eq("walk_in_check_in")
    end
  end

  describe "#mark_processed!" do
    it "marks the submission processed and links a volunteer" do
      submission = create(:inquiry_form_submission, processed: false)
      volunteer = create(:volunteer)

      submission.mark_processed!(volunteer)

      expect(submission.reload.processed?).to be true
      expect(submission.processed_at).to be_present
      expect(submission.volunteer).to eq(volunteer)
    end
  end

  describe "scopes" do
    it ".unprocessed returns only unprocessed submissions" do
      unprocessed = create(:inquiry_form_submission, processed: false)
      create(:inquiry_form_submission, :processed)

      expect(described_class.unprocessed).to contain_exactly(unprocessed)
    end

    it ".processed_submissions returns only processed submissions" do
      processed = create(:inquiry_form_submission, :processed)
      create(:inquiry_form_submission, processed: false)

      expect(described_class.processed_submissions).to contain_exactly(processed)
    end

    it ".from_source filters by source" do
      walk_in = create(:inquiry_form_submission, source: "walk_in_check_in")
      create(:inquiry_form_submission, source: "public_inquiry_form")

      expect(described_class.from_source("walk_in_check_in")).to contain_exactly(walk_in)
    end
  end
end
