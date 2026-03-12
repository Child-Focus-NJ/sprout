Given('an information session exists named {string}') do |name|
  @session = InformationSession.find_or_create_by!(name: name)
end



Given('the volunteer is registered for the session {string}') do |session_name|
  session = InformationSession.find_by!(name: session_name)
  volunteer = @volunteer || Volunteer.first
  SessionRegistration.find_or_create_by!(volunteer: volunteer, information_session: session)
end

When('I go to the sign-in page for session {string}') do |session_name|
  session = InformationSession.find_by!(name: session_name)

  visit "/information_sessions/#{session.id}/sign_in"
end

When('I check in the volunteer {string}') do |email|
  fill_in "Email", with: email
  click_button "Check in"
end

Then('the volunteer should be marked as attended for {string}') do |session_name|
  session = InformationSession.find_by!(name: session_name)
  volunteer = Volunteer.find_by!(email: "jane@childfocusnj.org")

  registration = SessionRegistration.find_by!(volunteer: volunteer, information_session: session)

  assert registration.respond_to?(:attended) && registration.attended
end

Then('the volunteer status should update to {string}') do |status_text|
  volunteer = Volunteer.find_by!(email: "jane@childfocusnj.org")

  assert_equal status_text, volunteer.status.to_s.tr("_", " ")
end

Then('the attendance should record a date and time') do
  volunteer = Volunteer.find_by!(email: "jane@childfocusnj.org")
  session   = InformationSession.find_by!(name: "March 2025 Info Session")
  registration = SessionRegistration.find_by!(volunteer: volunteer, information_session: session)

  timestamp =
    if registration.respond_to?(:checked_in_at) then registration.checked_in_at
    elsif registration.respond_to?(:attended_at) then registration.attended_at
    else nil
    end

  assert !timestamp.nil?
end

Then('an application email should be triggered for {string}') do |email|
  recipients = ActionMailer::Base.deliveries.map(&:to).flatten.compact.map(&:downcase)
  assert recipients.include?(email.downcase)
end

When('I attempt to check in an unregistered volunteer {string}') do |email|
  fill_in "Email", with: email
  click_button "Check in"
end

Then('I should be redirected to the inquiry form') do
  assert_current_path(/inquiry|inquiries|inquiry_form/i)
end

Then('I should see a prompt to add them to the system') do
  assert_text(/add|sign up|inquiry/i)
end
