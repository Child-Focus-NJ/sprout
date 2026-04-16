class User < ApplicationRecord
  enum :role, { admin: 0, staff: 1, viewer: 2 }

  has_many :notes, dependent: :destroy
  has_many :communications, foreign_key: :sent_by_user_id, dependent: :nullify
  has_many :status_changes, dependent: :nullify
  has_many :information_sessions_created,
    class_name: "InformationSession",
    foreign_key: :created_by_user_id,
    inverse_of: :created_by_user,
    dependent: :nullify

  validates :email, presence: true, uniqueness: true

  scope :active, -> { where(active: true) }

  def full_name
    [ first_name, last_name ].compact.join(" ")
  end

  def display_name
    full_name.presence || email.to_s.split("@").first.presence || "User"
  end
end
