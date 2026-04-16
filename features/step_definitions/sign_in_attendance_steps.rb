Given('an information session exists named {string}') do |name|
  @session = InformationSession.find_or_initialize_by(name: name)
  @session.scheduled_at ||= 1.day.from_now
  @session.location ||= "415 Hamburg Turnpike"
  @session.save!
end

Given('the volunteer is registered for the session {string}') do |session_name|
  session = InformationSession.find_by!(name: session_name)
  volunteer = @volunteer || Volunteer.first
  SessionRegistration.find_or_create_by!(volunteer: volunteer, information_session: session)
end

Given('I am on the sign-in page for session {string}') do |session_name|
  @session = InformationSession.find_or_initialize_by(name: session_name)
  @session.scheduled_at ||= 1.day.from_now
  @session.location ||= "415 Hamburg Turnpike"
  @session.save!
  visit "/information_sessions/#{@session.id}/sign_in"
end

When('I go to the sign-in page for session {string}') do |session_name|
  @session = InformationSession.find_by!(name: session_name)
  visit "/information_sessions/#{@session.id}/sign_in"
end

When('I check in the volunteer {string}') do |identifier|
  if identifier.include?("@")
    within("#walkin-sign-in") do
      fill_in "Email", with: identifier
      click_button "Check in walk-in"
    end
  else
    @volunteer = find_or_create_volunteer_by_name(identifier)
    click_button "Check in #{@volunteer.full_name}"
  end
end

Then('the volunteer should be marked as attended for {string}') do |session_name|
  session = InformationSession.find_by!(name: session_name)
  volunteer = Volunteer.find_by!(email: "jane@childfocusnj.org")

  registration = SessionRegistration.find_by!(volunteer: volunteer, information_session: session)

  assert registration.attended?
end

Then('the volunteer status should update to {string}') do |status_text|
  volunteer = Volunteer.find_by!(email: "jane@childfocusnj.org")

  assert_equal status_text, volunteer.status.to_s.tr("_", " ")
end

Then('the attendance should record a date and time') do
  volunteer = Volunteer.find_by!(email: "jane@childfocusnj.org")
  session   = InformationSession.find_by!(name: "March 2025 Info Session")
  registration = SessionRegistration.find_by!(volunteer: volunteer, information_session: session)

  assert registration.checked_in_at.present?
end

Then('an application email should be triggered for {string}') do |email|
  recipients = ActionMailer::Base.deliveries.flat_map { |m| Array.wrap(m.to) }.compact.map(&:downcase)
  assert_includes recipients, email.downcase
end

When('I attempt to check in an unregistered volunteer {string}') do |email|
  within("#walkin-sign-in") do
    fill_in "Email", with: email
    click_button "Check in walk-in"
  end
end

Then('I should be redirected to the inquiry form') do
  assert_match(/inquiry_form/i, current_path)
end

Then('I should see a prompt to add them to the system') do
  assert_text(/add|sign up|inquiry|walk-in|attendance/i)
end

When('I complete the walk-in inquiry for {string} with first name {string} and last name {string}') do |email, first_name, last_name|
  @walk_in_email = email
  fill_in "First name", with: first_name
  fill_in "Last name", with: last_name
  fill_in "Email", with: email
  fill_in "Phone", with: "5551234567"
  click_button "Submit and record attendance"
end

Then('a volunteer should exist for {string}') do |email|
  assert Volunteer.exists?(email: email)
end

Then('they should be marked as attended for {string}') do |session_name|
  session = InformationSession.find_by!(name: session_name)
  volunteer = Volunteer.find_by!(email: @walk_in_email)

  registration = SessionRegistration.find_by!(volunteer: volunteer, information_session: session)

  assert registration.attended?
end

Then('the walk-in volunteer status should reflect attended session') do
  volunteer = Volunteer.find_by!(email: @walk_in_email)

  assert_equal "attended session", volunteer.status.to_s.tr("_", " ")
end
