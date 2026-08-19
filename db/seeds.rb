# db/seeds.rb

puts "Seeding..."

# ── Users (Employees) ──────────────────────────────────────────────────────────
admin = User.find_or_create_by!(email: "admin@childfocusnj.org") do |u|
  u.first_name = "Admin"
  u.last_name  = "User"
  u.role       = 0
  u.active     = true
end

staff = User.find_or_create_by!(email: "staff@childfocusnj.org") do |u|
  u.first_name = "Sarah"
  u.last_name  = "Mitchell"
  u.role       = 0
  u.active     = true
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

# ── NJ Counties ─────────────────────────────────────────────────────────────
# Also created by db/migrate — see note above the referral sources block.
counties = [
  'Atlantic', 'Bergen', 'Burlington', 'Camden', 'Cape May', 'Cumberland', 'Essex', 'Gloucester', 'Hudson', 'Hunterdon',
  'Mercer', 'Middlesex', 'Monmouth', 'Morris', 'Ocean', 'Passaic', 'Salem', 'Somerset', 'Sussex', 'Union', 'Warren'
].map do |countyname|
  NjCounty.find_or_create_by!(name: countyname)
end

# ── Reminder Frequencies ───────────────────────────────────────────────────────
[ "Weekly", "Bi-weekly", "Monthly" ].each do |title|
  ReminderFrequency.find_or_create_by!(title: title)
end

# ── Information Sessions ───────────────────────────────────────────────────────
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

# ── Volunteers ─────────────────────────────────────────────────────────────────
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
  v.nj_county                 = counties.sample
  v.preferred_contact_method  = [ :email, :sms, :both ].sample

  v.save!
  v
end

# ── Session Registrations ──────────────────────────────────────────────────────
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
puts "Done! Seeded volunteers, sessions, tags, and frequencies."
