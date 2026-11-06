class Note < ApplicationRecord
  MAX_CONTENT_LENGTH = 1000

  enum :note_type, { general: 0, communication: 1, status_change: 2, system: 3 }

  belongs_to :volunteer
  belongs_to :user
  belongs_to :note_category

  validates :content, presence: true, length: { maximum: MAX_CONTENT_LENGTH }

  before_validation :assign_default_category, on: :create

  scope :recent, -> { order(created_at: :desc) }

  def edited?
    edited_at.present?
  end

  def editable_by?(editor)
    general? && editor.present? && user_id == editor.id
  end

  private

  def assign_default_category
    self.note_category ||= NoteCategory.default
  end
end
