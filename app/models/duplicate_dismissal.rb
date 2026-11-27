# A pair marked "Not a duplicate", stored lowest id first
class DuplicateDismissal < ApplicationRecord
  belongs_to :volunteer
  belongs_to :other_volunteer, class_name: "Volunteer"
  belongs_to :user, optional: true

  validate :lowest_id_first

  # Relies on the unique index, so a second click finds the existing row
  def self.dismiss!(volunteer, other_volunteer, user:)
    first, second = [ volunteer, other_volunteer ].sort_by(&:id)
    create_or_find_by!(volunteer: first, other_volunteer: second) { |dismissal| dismissal.user = user }
  end

  private

  def lowest_id_first
    return if volunteer_id.blank? || other_volunteer_id.blank? || volunteer_id < other_volunteer_id

    errors.add(:other_volunteer, "must be a different volunteer with a higher id")
  end
end
