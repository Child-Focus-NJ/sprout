class Note < ApplicationRecord
  MAX_CONTENT_LENGTH = 1000

  enum :note_type, { general: 0, communication: 1, status_change: 2, system: 3 }

  belongs_to :volunteer
  belongs_to :user

  validates :content, presence: true, length: { maximum: MAX_CONTENT_LENGTH }

  scope :recent, -> { order(created_at: :desc) }
end
