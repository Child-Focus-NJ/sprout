class ReferralSource < ApplicationRecord
  has_many :volunteers, dependent: :nullify
  has_many :inquiry_form_submissions, dependent: :nullify

  validates :name, presence: true, uniqueness: true

  scope :active, -> { where(active: true) }
  scope :menu_order, -> { order(Arel.sql("name = 'Other'"), :name) }
  scope :choices_for, ->(selected_id) { active.or(where(id: selected_id)).menu_order }
end
