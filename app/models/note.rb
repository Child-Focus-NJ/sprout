class Note < ApplicationRecord
  enum :note_type, { general: 0, communication: 1, status_change: 2, system: 3 }

  belongs_to :volunteer
  belongs_to :user

  validates :content, presence: true

  scope :recent, -> { order(created_at: :desc) }
end
