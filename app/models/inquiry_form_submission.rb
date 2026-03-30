class InquiryFormSubmission < ApplicationRecord
  belongs_to :volunteer, optional: true

  scope :unprocessed, -> { where(processed: false) }
  scope :processed_submissions, -> { where(processed: true) }
  scope :from_source, ->(source) { where(source: source) }

  def mark_processed!(volunteer = nil)
    update!(processed: true, processed_at: Time.current, volunteer: volunteer)
  end
end
