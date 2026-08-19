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
    email = auth.info.email.to_s.strip.downcase
    user = find_by(google_uid: auth.uid) || find_by(email: email)

    attrs = {
      google_uid: auth.uid,
      email: email,
      first_name: auth.info.first_name.presence || name_parts.first,
      last_name: auth.info.last_name.presence || name_parts[1..].join(" ").presence,
      avatar_url: auth.info.image.presence
    }

    if user
      user.update!(
        google_uid: attrs[:google_uid],
        first_name: attrs[:first_name] || user.first_name,
        last_name: attrs[:last_name] || user.last_name,
        avatar_url: attrs[:avatar_url] || user.avatar_url
      )
      user
    else
      create!(attrs)
    end
  end

  def self.allowed_email?(email)
    email&.end_with?("@passaiccountycasa.org", "@nyu.edu") || false
  end
end
