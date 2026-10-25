# db/seeds.rb

puts "Seeding..."

# ── Users (Employees) ──────────────────────────────────────────────────────────
# Seeded in every environment: the primary CASA admin (sprout@), the Child Focus
# admin, and the launch admins. Everyone else is added afterward through the
# whitelist on the Employees tab.
[
  { email: "sprout@passaiccountycasa.org",   first_name: "Sprout",   last_name: "Admin" },
  { email: "admin@childfocusnj.org",         first_name: "Admin",    last_name: "User" },
  { email: "az2924@nyu.edu",                 first_name: "Alisha",   last_name: "Zaman" },
  { email: "wr2256@nyu.edu",                 first_name: "Will",     last_name: "Roche" },
  { email: "sw6002@nyu.edu",                 first_name: "Sufyan",   last_name: "Waryah" },
  { email: "erica@passaiccountycasa.org",    first_name: "Erica",    last_name: "Fischer-Kaslander" },
  { email: "michelle@passaiccountycasa.org", first_name: "Michelle", last_name: "Schaefer" },
  { email: "mike@passaiccountycasa.org",     first_name: "Mike" },
  { email: "peter.depasquale@nyu.edu",       first_name: "Peter",    last_name: "DePasquale" }
].each do |attrs|
  # find_or_initialize_by (not find_or_create_by!) so someone who signed in and
  # was auto-created as a user before this ran still gets promoted (re-running
  # also re-promotes anyone demoted since). Names Google already filled in and
  # deactivations are left alone.
  u = User.find_or_initialize_by(email: attrs[:email])
  u.first_name ||= attrs[:first_name]
  u.last_name  ||= attrs[:last_name]
  u.role         = :admin
  u.save!
end

# ── Features ───────────────────────────────────────────────────────────────────
# Also created by db/migrate (SeedFeatures) — see the note on the referral
# sources block below.
{
  "system_management" => "Admin tab: reminder frequencies, volunteer tags, employees, referral sources",
  "users" => "Adding, editing, and deactivating employees",
  "reminder_frequencies" => "Managing reminder frequency options",
  "volunteer_tags" => "Managing volunteer tag options",
  "referral_sources" => "Managing referral source options",
  "admin_settings" => "Admin settings page",
  "admin_data_exports" => "Full data export",
  "admin_usage_reports" => "Admin-only usage report"
}.each do |key, description|
  Feature.find_or_create_by!(key: key) do |f|
    f.admin_only = true
    f.description = description
  end
end

# ── Referral Sources ───────────────────────────────────────────────────────────
# Also created by db/migrate (SeedNjCountiesAndReferralSources) for
# environments that replay real pending migrations. But as of Rails 8,
# db:migrate against a *fresh/empty* database implicitly loads db/schema.rb
# first and marks migrations at/below that version as applied WITHOUT running
# their code (rails/rails#53899) — so that migration alone isn't reliable on
# a brand-new database. find_or_create_by! here makes this self-healing
# regardless of which path Rails takes.
sources = [ "Facebook", "Instagram", "Word of Mouth", "Website", "Flyer", "School", "Other" ].map do |name|
  ReferralSource.find_or_create_by!(name: name)
end

# ── Volunteer Tags ─────────────────────────────────────────────────────────────
[ "Bilingual", "Available Weekends", "Has Prior Experience", "Flexible Schedule" ].each do |title|
  VolunteerTag.find_or_create_by!(title: title)
end

# ── NJ Vicinages ─────────────────────────────────────────────────────────────
# Also created by db/migrate — see note above the referral sources block.
vicinages = %w[ Passaic Union Either Unknown ].map do |vicinagename|
  Vicinage.find_or_create_by!(name: vicinagename)
end

# ── Reminder Frequencies ───────────────────────────────────────────────────────
[ "Weekly", "Bi-weekly", "Monthly" ].each do |title|
  ReminderFrequency.find_or_create_by!(title: title)
end

# ── Communication Templates ─────────────────────────────────────────────────────
follow_up_copy = {
  inquiry: {
    30 => "It's been a month since you reached out. We'd still love to have you join us. Reply anytime with questions.",
    60 => "Just checking in again. Spots are still open at our upcoming information sessions if you're ready to take the next step.",
    90 => "We haven't heard from you in a few months. If volunteering with us is still on your mind, we're here whenever you're ready.",
    180 => "It's been half a year since your inquiry. No pressure at all. Just let us know if you'd like to pick things back up."
  },
  application_eligible: {
    30 => "Thanks again for attending your information session! When you get a chance, we'd love for you to register for a follow-up session.",
    60 => "Still hoping to see you at another session soon. Let us know if you have any questions about next steps.",
    90 => "It's been a few months since your info session. We'd still love to have you continue on toward becoming a volunteer.",
    180 => "It's been six months since you attended an info session. If you're still interested, we'd love to help you get back on track."
  },
  application_sent: {
    30 => "Just a reminder that your volunteer application is ready and waiting. Let us know if you have questions filling it out.",
    60 => "We noticed your application hasn't been submitted yet. We're happy to help if anything is holding you up.",
    90 => "Your application has been open for a few months now. Reach out anytime if you'd like help finishing it.",
    180 => "It's been six months since we sent your application. If you're still interested in volunteering, we'd love to help you finish up."
  }
}

follow_up_copy.each do |stage, by_days|
  by_days.each do |days, body|
    CommunicationTemplate.find_or_create_by!(name: "#{stage.to_s.humanize} #{days}-day follow-up") do |t|
      t.subject = "Still thinking about volunteering, {{first_name}}?"
      t.body = "Hi {{first_name}}, #{body}\n\n— {{organization_name}}"
      t.funnel_stage = stage
      t.template_type = :email
      t.trigger_type = :interval
      t.interval_days = days
      t.active = true
    end
  end
end

puts "  Created communication templates"

# ── Demo data ──────────────────────────────────────────────────────────────────
# Sample staff, sessions, volunteers, and registrations for local/dev only, so
# running db:seed against production never adds fake records.
unless Rails.env.production?
  admin = User.find_by!(email: "sprout@passaiccountycasa.org")

  User.find_or_create_by!(email: "staff@childfocusnj.org") do |u|
    u.first_name = "Sarah"
    u.last_name  = "Mitchell"
    u.role       = :user
    u.active     = true
  end

  # ── Information Sessions ─────────────────────────────────────────────────────
  sessions = [
    { name: "May Info Session",    location: "Zoom",                 scheduled_at: 2.days.from_now,   capacity: 30, zoom_link: "https://zoom.us/j/111111111" },
    { name: "May In-Person",       location: "415 Hamburg Turnpike", scheduled_at: 5.days.from_now,   capacity: 15 },
    { name: "June Virtual A",      location: "Zoom",                 scheduled_at: 2.weeks.from_now,  capacity: 25, zoom_link: "https://zoom.us/j/222222222" },
    { name: "June In-Person",      location: "415 Hamburg Turnpike", scheduled_at: 3.weeks.from_now,  capacity: 20 },
    { name: "Summer Virtual",      location: "Zoom",                 scheduled_at: 5.weeks.from_now,  capacity: 30, zoom_link: "https://zoom.us/j/333333333" },
    { name: "Summer In-Person",    location: "415 Hamburg Turnpike", scheduled_at: 6.weeks.from_now,  capacity: 20 }
  ]

  info_sessions = sessions.map do |attrs|
    InformationSession.find_or_create_by!(name: attrs[:name]) do |s|
      s.scheduled_at    = attrs[:scheduled_at]
      s.location        = attrs[:location]
      s.capacity        = attrs[:capacity]
      s.zoom_link       = attrs[:zoom_link]
      s.active          = true
      s.created_by_user = admin
    end
  end

  # ── Volunteers ───────────────────────────────────────────────────────────────
  # Keep the demo dataset tiny so local/dev lists stay easy to scan.
  volunteer_data = [
    { first_name: "Harry", last_name: "Kane",   email: "harry-kane@childfocusnj.org", inquiry_date: Date.new(2026, 4, 1),  stage: :inquiry },
    { first_name: "Sofia", last_name: "Reyes",  email: "sofia.reyes@example.com",     inquiry_date: Date.new(2024, 4, 14), stage: :application_sent,     application_sent_at: Date.new(2024, 5, 1) },
    { first_name: "Hana",  last_name: "Kimura", email: "hana.kimura@example.com",     inquiry_date: Date.new(2026, 3, 22), stage: :application_eligible, first_session_attended_at: Date.new(2026, 4, 10) }
  ]

  volunteers = volunteer_data.map do |attrs|
    v = Volunteer.find_or_initialize_by(email: attrs[:email])

    v.first_name                = attrs[:first_name]
    v.last_name                 = attrs[:last_name]
    v.current_funnel_stage      = attrs[:stage]
    v.inquiry_date              = attrs[:inquiry_date]
    v.application_submitted_at  = attrs[:application_submitted_at]
    v.application_sent_at       = attrs[:application_sent_at]
    v.first_session_attended_at = attrs[:first_session_attended_at]
    v.became_inactive_at        = attrs[:became_inactive_at]
    v.inactive_reason           = attrs[:inactive_reason]
    v.referral_source           = sources.sample
    v.vicinage                  = vicinages.sample
    v.preferred_contact_method  = [ :email, :sms, :both ].sample

    v.save!
    v
  end

  # ── Session Registrations ────────────────────────────────────────────────────
  eligible_volunteers = volunteers.select { |v| v.application_eligible? || v.application_sent? || v.applied? }

  info_sessions.each do |session|
    attendees = eligible_volunteers.sample([ eligible_volunteers.size, 2 ].min)
    attendees.each do |volunteer|
      next if SessionRegistration.exists?(volunteer: volunteer, information_session: session)

      SessionRegistration.create!(
        volunteer:           volunteer,
        information_session: session,
        status:              :registered,
        registered_at:       Time.current - rand(1..10).days
      )
    end
  end

  puts "  Created session registrations"

  puts "  Created #{volunteers.size} volunteers"
end

puts "Done!"
