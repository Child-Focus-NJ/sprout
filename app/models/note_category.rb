class NoteCategory < ApplicationRecord
  DEFAULT_KEY = "note".freeze
  SESSION_OUTCOME_KEYS = %w[attended_info_session no_show rescheduled cancelled].freeze
  DEACTIVATED_KEY = "deactivated".freeze

  has_many :notes

  validates :name, presence: true, uniqueness: true

  before_destroy :prevent_removing_built_in
  before_destroy :move_notes_to_default

  scope :ordered, -> { order(:id) }
  scope :plain, -> { where(key: nil).or(where(key: DEFAULT_KEY)) }

  def self.default
    find_or_create_by!(key: DEFAULT_KEY) { |category| category.name = "Note" }
  end

  def built_in?
    key.present?
  end

  def session_outcome?
    SESSION_OUTCOME_KEYS.include?(key)
  end

  def rescheduled?
    key == "rescheduled"
  end

  def deactivates?
    key == DEACTIVATED_KEY
  end

  def updates_records?
    session_outcome? || deactivates?
  end

  private

  def prevent_removing_built_in
    return unless built_in?

    errors.add(:base, "#{name} is built in and can't be removed")
    throw :abort
  end

  def move_notes_to_default
    return unless notes.exists?

    notes.update_all(note_category_id: self.class.default.id, updated_at: Time.current)
  end
end
