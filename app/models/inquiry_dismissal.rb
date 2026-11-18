# A staff member dismissed this volunteer from the New inquiries column on their dashboard
class InquiryDismissal < ApplicationRecord
  belongs_to :user
  belongs_to :volunteer

  validates :volunteer_id, uniqueness: { scope: :user_id }
end
