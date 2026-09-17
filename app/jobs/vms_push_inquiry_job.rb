# Pushes a newly-created Sprout inquiry out to the external VMS as a new
# inquiry record, then stores the VMS's encrypted_id on the volunteer so
# later operations (edit/delete, or matching an inbound pull) can address
# the same record
class VmsPushInquiryJob < ApplicationJob
  queue_as :default

  def perform(volunteer_id)
    volunteer = Volunteer.find(volunteer_id)
    inquired_on = (volunteer.inquiry_date || volunteer.created_at || Time.current).to_date

    encrypted_id = ExternalVmsSync.new.create_inquiry!(
      first_name: volunteer.first_name,
      last_name: volunteer.last_name,
      phone: volunteer.phone,
      email: volunteer.email,
      inquired: inquired_on.strftime("%-m/%-d/%Y")
    )

    volunteer.update!(external_id: encrypted_id, external_synced_at: Time.current) if encrypted_id.present?
  end
end
