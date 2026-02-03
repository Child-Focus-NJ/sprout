class ReferralSource < ApplicationRecord
  has_many :volunteers, dependent: :nullify

  validates :name, presence: true, uniqueness: true

  scope :active, -> { where(active: true) }
end
