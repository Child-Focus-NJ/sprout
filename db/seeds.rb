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
sources = [ "Facebook", "Instagram", "Word of Mouth", "Website", "Flyer", "School", "Other" ].map do |name|
  ReferralSource.find_or_create_by!(name: name)
end

# ── Volunteer Tags ─────────────────────────────────────────────────────────────
[ "Bilingual", "Available Weekends", "Has Prior Experience", "Flexible Schedule" ].each do |title|
  VolunteerTag.find_or_create_by!(title: title)
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
volunteer_data = [
  # 2022
  { first_name: "Olivia",   last_name: "Grant",     email: "olivia.grant@example.com",    inquiry_date: Date.new(2022, 2, 10),  stage: :applied,              application_submitted_at: Date.new(2022, 3, 5) },
  { first_name: "Marcus",   last_name: "Webb",      email: "marcus.webb@example.com",     inquiry_date: Date.new(2022, 4, 18),  stage: :inactive,             became_inactive_at: Date.new(2022, 6, 1),  inactive_reason: :no_response },
  { first_name: "Priya",    last_name: "Nair",      email: "priya.nair@example.com",      inquiry_date: Date.new(2022, 7, 3),   stage: :applied,              application_submitted_at: Date.new(2022, 8, 14) },
  { first_name: "Daniel",   last_name: "Foster",    email: "daniel.foster@example.com",   inquiry_date: Date.new(2022, 9, 22),  stage: :applied,              application_submitted_at: Date.new(2022, 10, 30) },

  # 2023
  { first_name: "Simone",   last_name: "Clarke",    email: "simone.clarke@example.com",   inquiry_date: Date.new(2023, 1, 15),  stage: :applied,              application_submitted_at: Date.new(2023, 2, 20) },
  { first_name: "Tyler",    last_name: "Brooks",    email: "tyler.brooks@example.com",    inquiry_date: Date.new(2023, 3, 8),   stage: :inactive,             became_inactive_at: Date.new(2023, 4, 10), inactive_reason: :time_expired },
  { first_name: "Aisha",    last_name: "Okafor",    email: "aisha.okafor@example.com",    inquiry_date: Date.new(2023, 5, 19),  stage: :applied,              application_submitted_at: Date.new(2023, 6, 25) },
  { first_name: "Connor",   last_name: "Murphy",    email: "connor.murphy@example.com",   inquiry_date: Date.new(2023, 6, 2),   stage: :applied,              application_submitted_at: Date.new(2023, 7, 8) },
  { first_name: "Leila",    last_name: "Hassan",    email: "leila.hassan@example.com",    inquiry_date: Date.new(2023, 8, 30),  stage: :inactive,             became_inactive_at: Date.new(2023, 10, 1), inactive_reason: :cancelled },
  { first_name: "James",    last_name: "Osei",      email: "james.osei@example.com",      inquiry_date: Date.new(2023, 10, 5),  stage: :applied,              application_submitted_at: Date.new(2023, 11, 12) },

  # 2024
  { first_name: "Natalie",  last_name: "Russo",     email: "natalie.russo@example.com",   inquiry_date: Date.new(2024, 1, 9),   stage: :applied,              application_submitted_at: Date.new(2024, 2, 17) },
  { first_name: "Kwame",    last_name: "Asante",    email: "kwame.asante@example.com",    inquiry_date: Date.new(2024, 2, 28),  stage: :applied,              application_submitted_at: Date.new(2024, 4, 3) },
  { first_name: "Sofia",    last_name: "Reyes",     email: "sofia.reyes@example.com",     inquiry_date: Date.new(2024, 4, 14),  stage: :application_sent,     application_sent_at: Date.new(2024, 5, 1) },
  { first_name: "Ben",      last_name: "Kowalski",  email: "ben.kowalski@example.com",    inquiry_date: Date.new(2024, 5, 22),  stage: :application_eligible, first_session_attended_at: Date.new(2024, 6, 10) },
  { first_name: "Yara",     last_name: "Mansour",   email: "yara.mansour@example.com",    inquiry_date: Date.new(2024, 7, 7),   stage: :applied,              application_submitted_at: Date.new(2024, 8, 19) },
  { first_name: "Ethan",    last_name: "Park",      email: "ethan.park@example.com",      inquiry_date: Date.new(2024, 8, 3),   stage: :inactive,             became_inactive_at: Date.new(2024, 9, 15), inactive_reason: :no_response },
  { first_name: "Amara",    last_name: "Diallo",    email: "amara.diallo@example.com",    inquiry_date: Date.new(2024, 10, 18), stage: :applied,              application_submitted_at: Date.new(2024, 11, 30) },
  { first_name: "Lucas",    last_name: "Ferreira",  email: "lucas.ferreira@example.com",  inquiry_date: Date.new(2024, 11, 5),  stage: :applied,              application_submitted_at: Date.new(2024, 12, 10) },

  # 2025
  { first_name: "Mia",      last_name: "Thornton",  email: "mia.thornton@example.com",    inquiry_date: Date.new(2025, 1, 20),  stage: :applied,              application_submitted_at: Date.new(2025, 2, 28) },
  { first_name: "Jordan",   last_name: "Hayes",     email: "jordan.hayes@example.com",    inquiry_date: Date.new(2025, 2, 14),  stage: :applied,              application_submitted_at: Date.new(2025, 3, 22) },
  { first_name: "Fatima",   last_name: "Al-Amin",   email: "fatima.alamin@example.com",   inquiry_date: Date.new(2025, 3, 5),   stage: :application_sent,     application_sent_at: Date.new(2025, 4, 1) },
  { first_name: "Noah",     last_name: "Patel",     email: "noah.patel@example.com",      inquiry_date: Date.new(2025, 4, 12),  stage: :applied,              application_submitted_at: Date.new(2025, 5, 20) },
  { first_name: "Camille",  last_name: "Dubois",    email: "camille.dubois@example.com",  inquiry_date: Date.new(2025, 6, 8),   stage: :application_eligible, first_session_attended_at: Date.new(2025, 7, 1) },
  { first_name: "Isaac",    last_name: "Gomez",     email: "isaac.gomez@example.com",     inquiry_date: Date.new(2025, 7, 25),  stage: :inquiry },
  { first_name: "Zoe",      last_name: "Lindqvist", email: "zoe.lindqvist@example.com",   inquiry_date: Date.new(2025, 9, 3),   stage: :applied,              application_submitted_at: Date.new(2025, 10, 15) },
  { first_name: "Rafael",   last_name: "Santos",    email: "rafael.santos@example.com",   inquiry_date: Date.new(2025, 10, 17), stage: :inactive,             became_inactive_at: Date.new(2025, 11, 20), inactive_reason: :other },

  # 2026
  { first_name: "Imani",    last_name: "Wallace",   email: "imani.wallace@example.com",   inquiry_date: Date.new(2026, 1, 6),   stage: :applied,              application_submitted_at: Date.new(2026, 2, 10) },
  { first_name: "Leo",      last_name: "Nguyen",    email: "leo.nguyen@example.com",      inquiry_date: Date.new(2026, 2, 18),  stage: :application_sent,     application_sent_at: Date.new(2026, 3, 5) },
  { first_name: "Hana",     last_name: "Kimura",    email: "hana.kimura@example.com",     inquiry_date: Date.new(2026, 3, 22),  stage: :application_eligible, first_session_attended_at: Date.new(2026, 4, 10) },
  { first_name: "Malik",    last_name: "Owens",     email: "malik.owens@example.com",     inquiry_date: Date.new(2026, 4, 1),   stage: :inquiry },
  { first_name: "Elena",    last_name: "Vasquez",   email: "elena.vasquez@example.com",   inquiry_date: Date.new(2026, 4, 28),  stage: :inquiry }
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
  v.preferred_contact_method  = [ :email, :sms, :both ].sample

  v.save!
  v
end

# ── Session Registrations ──────────────────────────────────────────────────────
eligible_volunteers = volunteers.select { |v| v.application_eligible? || v.application_sent? || v.applied? }

info_sessions.each do |session|
  attendees = eligible_volunteers.sample(rand(3..8))
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
puts "Done! Seeded volunteers, sessions, tags, frequencies, and referral sources."
