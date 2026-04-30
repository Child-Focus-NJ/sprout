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

  def self.from_omniauth(auth)
  name_parts = auth.info.name.to_s.split
  user = find_or_create_by!(google_uid: auth.uid) do |u|
    u.email = auth.info.email
    u.first_name = auth.info.first_name.presence || name_parts.first
    u.last_name = auth.info.last_name.presence || name_parts[1..].join(" ").presence
    u.avatar_url = auth.info.image.presence
  end
  user.update!(
    first_name: auth.info.first_name.presence || name_parts.first || user.first_name,
    last_name: auth.info.last_name.presence || name_parts[1..].join(" ").presence || user.last_name,
    avatar_url: auth.info.image.presence || user.avatar_url
  )
  user
end

def self.allowed_email?(email)
  email&.end_with?("@passaiccountycasa.org", "@nyu.edu") || false
end
end
