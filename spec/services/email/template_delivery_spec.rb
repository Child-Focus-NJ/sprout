# frozen_string_literal: true

require "rails_helper"

RSpec.describe Email::TemplateDelivery do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:template) do
    CommunicationTemplate.create!(
      name: "Invite", subject: "Hi {{first_name}}", body: "Hello {{full_name}}",
      template_type: :email, funnel_stage: :inquiry, trigger_type: :manual, active: true
    )
  end

  describe ".deliver_all_later" do
    it "records a filled-in pending email per volunteer and queues one job each" do
      jane = create(:volunteer, first_name: "Jane", last_name: "Doe")
      omar = create(:volunteer, first_name: "Omar", last_name: "Ali")

      result = nil
      expect do
        result = described_class.deliver_all_later(Volunteer.where(id: [ jane.id, omar.id ]), template: template, sent_by_user: user)
      end.to have_enqueued_job(SendTemplateEmailJob).exactly(2).times

      expect(result).to eq(described_class::Result.new(queued: 2, not_queued: 0))
      expect(jane.communications.sole).to have_attributes(
        communication_type: "email", status: "pending", communication_template: template, sent_by_user: user,
        subject: "Hi Jane", body: "Hello Jane Doe", email_to: jane.email
      )
      expect(omar.communications.sole.subject).to eq("Hi Omar")
    end

    it "uses the same number of queries however many volunteers are selected" do
      template
      create_list(:volunteer, 2)
      few = sql_count { described_class.deliver_all_later(Volunteer.all, template: template) }
      Communication.delete_all
      create_list(:volunteer, 8)
      many = sql_count { described_class.deliver_all_later(Volunteer.all, template: template) }

      expect(many).to eq(few)
    end
  end

  def sql_count
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name].in?([ "SCHEMA", "TRANSACTION" ]) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    count
  end
end
