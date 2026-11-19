# A staff member dismissed this volunteer from the New inquiries column on their dashboard.
# updated_at is when they last pressed ×. It hides what happened up to then, so a volunteer who
# comes back afterwards shows again. The unique index on user and volunteer keeps it to one row,
# and lets a second × find that row instead of failing, so there's no uniqueness validation here.
class InquiryDismissal < ApplicationRecord
  belongs_to :user
  belongs_to :volunteer

  def self.dismiss!(user, volunteer)
    dismissal = create_or_find_by!(user: user, volunteer: volunteer)
    dismissal.touch unless dismissal.previously_new_record?
    dismissal
  end
end
