class User < ApplicationRecord
  enum :role, { admin: 0, staff: 1, viewer: 2 }

  has_many :notes, dependent: :destroy
  has_many :communications, foreign_key: :sent_by_user_id, dependent: :nullify
  has_many :status_changes, dependent: :nullify

  validates :email, presence: true, uniqueness: true

  scope :active, -> { where(active: true) }

  def full_name
    [ first_name, last_name ].compact.join(" ")
  end
end
