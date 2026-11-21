require "rails_helper"

RSpec.describe VolunteerMerge do
  let(:admin) { create(:user, role: :admin) }
  let!(:older) do
    create(:volunteer, first_name: "Maria", last_name: "Lopez", email: "maria.lopez@gmail.com", phone: "(973) 555-0182",
                       created_at: 20.days.ago, inquiry_date: 20.days.ago)
  end
  let!(:newer) do
    create(:volunteer, first_name: "maria", last_name: "lopez", email: "mlopez@work.org", phone: "973-555-0199",
                       created_at: 2.days.ago, inquiry_date: 2.days.ago)
  end

  # Newer first, so it also checks the older record is the one kept
  def merge(choices = {})
    described_class.new(newer, older, choices: choices, user: admin).call
  end

  it "keeps the older record with the name, email, phone and status staff picked, and deletes the newer one" do
    newer.update!(current_funnel_stage: :application_eligible)

    kept = merge("name" => older.id, "email" => newer.id, "phone" => newer.id, "status" => newer.id)

    expect(kept).to eq(older)
    expect(Volunteer.where(id: newer.id)).not_to exist
    expect(kept.reload).to have_attributes(full_name: "Maria Lopez", email: "mlopez@work.org", phone: "973-555-0199",
                                           current_funnel_stage: "application_eligible")
    expect(kept.status_changes.last).to have_attributes(from_funnel_stage: "Inquiry", to_funnel_stage: "Application eligible",
                                                        user: admin)
  end

  it "keeps the older record's values for anything not chosen" do
    kept = merge

    expect(kept.reload).to have_attributes(full_name: "Maria Lopez", email: "maria.lopez@gmail.com", phone: "(973) 555-0182")
  end

  it "moves notes, emails and texts, status history and reminders to the kept profile" do
    note = newer.add_staff_note!(content: "Called about October", user: admin)
    text = Communication.create!(volunteer: newer, communication_type: :sms, body: "See you Tuesday")
    history = newer.status_changes.create!(from_funnel_stage: "Inquiry", to_funnel_stage: "Application eligible")
    template = CommunicationTemplate.create!(name: "Follow up", body: "Hi", funnel_stage: :inquiry)
    reminder = ScheduledReminder.create!(volunteer: newer, communication_template: template, scheduled_for: 1.day.from_now)

    merge

    expect([ note, text, history, reminder ].map { |record| record.reload.volunteer_id }).to all(eq(older.id))
  end

  it "cancels a pending reminder the kept profile already has, so it isn't sent twice" do
    template = CommunicationTemplate.create!(name: "Follow up", body: "Hi", funnel_stage: :inquiry)
    sent = ScheduledReminder.create!(volunteer: older, communication_template: template, scheduled_for: 3.days.ago, status: :sent)
    repeat = ScheduledReminder.create!(volunteer: newer, communication_template: template, scheduled_for: 1.day.from_now)

    merge

    expect(sent.reload).to be_sent
    expect(repeat.reload).to have_attributes(volunteer_id: older.id, status: "cancelled")
  end

  it "moves info session registrations, keeping the attended one when both signed up for the same session" do
    shared_session = create(:information_session)
    other_session = create(:information_session)
    create(:session_registration, volunteer: older, information_session: shared_session, status: :no_show)
    attended = create(:session_registration, volunteer: newer, information_session: shared_session, status: :attended)
    other = create(:session_registration, volunteer: newer, information_session: other_session)

    merge

    expect(older.session_registrations.reload).to contain_exactly(attended, other)
    expect(attended.reload).to be_attended
  end

  it "keeps the earliest date for each step and fills in details only the newer record has" do
    vicinage = create(:vicinage)
    newer.update!(first_session_attended_at: 1.day.ago, vicinage: vicinage)

    kept = merge

    expect(kept.reload.vicinage).to eq(vicinage)
    expect(kept.inquiry_date).to be_within(1.second).of(20.days.ago)
    expect(kept.first_session_attended_at).to be_within(1.second).of(1.day.ago)
  end

  it "keeps a phone number when the chosen record has none" do
    older.update!(phone: nil)

    expect(merge("phone" => older.id).reload.phone).to eq("973-555-0199")
  end

  it "points referrals at the kept profile, and never has it refer itself" do
    older.update!(referred_by_volunteer: newer)
    referred = create(:volunteer, referred_by_volunteer: newer)

    merge

    expect(referred.reload.referred_by_volunteer).to eq(older)
    expect(older.reload.referred_by_volunteer).to be_nil
  end

  it "keeps 'Not a duplicate' decisions about the newer record" do
    sam = create(:volunteer, first_name: "Sam", last_name: "Reed")
    DuplicateDismissal.dismiss!(newer, sam, user: admin)

    merge

    expect(DuplicateDismissal.sole).to have_attributes(volunteer: older, other_volunteer: sam, user: admin)
  end

  it "adds a note to the kept profile saying what was merged in" do
    merge

    expect(older.notes.sole).to have_attributes(note_type: "system", user: admin)
    expect(older.notes.sole.content).to start_with(
      "Merged in a duplicate record for maria lopez (mlopez@work.org, 973-555-0199), added #{2.days.ago.strftime('%b %-d, %Y')}."
    )
  end
end
