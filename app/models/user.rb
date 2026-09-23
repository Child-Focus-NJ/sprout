class User < ApplicationRecord
  enum :role, { admin: 0, user: 1 }

  before_validation :normalize_email
  before_save :clear_google_uid_if_email_changed

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
    email = normalize_email(auth.info.email)
    user = find_by(google_uid: auth.uid) || find_by(email: email)
    return nil unless user

    name_parts = auth.info.name.to_s.split
    user.update!(
      google_uid: auth.uid,
      first_name: auth.info.first_name.presence || name_parts.first || user.first_name,
      last_name: auth.info.last_name.presence || name_parts[1..].join(" ").presence || user.last_name,
      avatar_url: auth.info.image.presence || user.avatar_url
    )
    user
  end

  def self.normalize_email(value)
    value.to_s.strip.downcase.presence
  end

  private

  def normalize_email
    self.email = self.class.normalize_email(email)
  end

  def clear_google_uid_if_email_changed
    self.google_uid = nil if persisted? && email_changed?
  end
end
