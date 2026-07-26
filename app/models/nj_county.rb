class NjCounty < ApplicationRecord
  has_many :volunteers, dependent: :nullify
  has_many :inquiry_form_submissions, dependent: :nullify

  validates :name, presence: true, uniqueness: true

  scope :alphabetical, -> { order(:name) }
end
