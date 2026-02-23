# function to change format of date and time from UI
def parse_session_datetime(month, day, year, hour, minute, meridian)
  year += 2000 if year < 100
  hour += 12 if meridian.upcase == "PM" && hour < 12
  hour = 0 if meridian.upcase == "AM" && hour == 12
  DateTime.new(year, month, day, hour, minute)
end

Given('the following information sessions exist:') do |table|
    table.hashes.each do |row|
        FactoryBot.create(:information_session,
            capacity: row['capacity'],
            scheduled_at: Date.parse(row['date']),
            name: row['name'],
            location: row['location']
        )
    end
end

Given('the following attendees exist:') do |table|
    table.hashes.each do |row|
        FactoryBot.create(:volunteer,
            first_name: row['name'],
            last_name: row['email'],
            email: row['phone'] 
        )
    end
end

Given('I am logged in as a system administrator') do
    OmniAuth.config.test_mode = true #don't need to have actual google account
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(provider: 'google_oauth2', uid: '123456', info: { email: 'admin@example.com', name: 'System Admin' })
    User.find_or_create_by!(email: 'admin@example.com', role: 'system_admin')

    #login with google auth
    visit '/auth/google_oauth2'
end

Given('I am on the information session management page') do
    visit information_sessions_path
end

Given('I am on the create new information session page') do
    visit new_information_session_path
end

Given('I have filled out the {string} field with {string}') do |field_name, value|
    fill_in field_name, with: value
end

Given('I have clicked the {string} button') do |button|
  click_button button
end

Then('an information session with date {int}\/{int}\/{int} and time {int}:{int} {word} should be on the list of information sessions') do |month, day, year, hour, minute, meridian|
    dt = parse_session_datetime(month, day, year, hour, minute, meridian)
    expect(page).to have_content(dt.strftime("%m/%d/%Y %I:%M %p"))
end

Then('an information session with date {int}\/{int}\/{int} and time {int}:{int} {word} should be on the inquiry form') do |month, day, year, hour, minute, meridian|
    visit inquiry_form_path # might need to change once we implement
    dt = parse_session_datetime(month, day, year, hour, minute, meridian)

    expect(page).to have_content(dt.strftime("%m/%d/%Y %I:%M %p"))
end

Then('the information session with date {int}\/{int}\/{int} and time {int}:{int} {word} should have a Zoom link for the meeting') do |month, day, year, hour, minute, meridian|
    dt = parse_session_datetime(month, day, year, hour, minute, meridian)
    session_time_str = dt.strftime("%m/%d/%Y %I:%M %p")
    session_element = find('.information-session', text: session_time_str)

    expect(session_element).to have_link('Zoom') # might need to change when implemented
end

Then('a message that says {string} will appear') do |message|
    expect(page).to have_content(message)
end

Then('an information session with date {int}\/{int}\/{int} and time {int}:{int} {word} should not be on the list of information sessions') do |month, day, year, hour, minute, meridian|
    dt = parse_session_datetime(month, date, year, hour, minute, meridian)
    displayed_text = session_datetime.strftime("%B %-d, %Y %-l:%M %p").strip
    expect(page).not_to have_content(displayed_text)
end

Then('an information session with date {int}\/{int}\/{int} and time {int}:{int} {word} should not be on the inquiry form') do |month, day, year, hour, minute, meridian|
    visit inquiry_form_path
    dt = parse_session_datetime(month, date, year, hour, minute, meridian)
    displayed_text = session_datetime.strftime("%B %-d, %Y %-l:%M %p").strip
    expect(page).not_to have_content(displayed_text)
end

Given('I am on the edit page for information session with date {int}\/{int}\/{int} and time {int}:{int} {word}') do |month, day, year, hour, minute, meridian|
    dt = parse_session_datetime(month, day, year, hour, minute, meridian)
    session = InformationSession.find_by(scheduled_at: dt)
    visit edit_information_session_path(session.id)
end

Given('I edit the {string} field to be {string}') do |field_name, value|
  select value, from: field_name
end

Given('I click the {string} button') do |button|
  click_button button
end

Given('I click the {string} button for attendee with name {string}') do |button, name|
  row = find('tr', text: name)

  row.click_button(button)
end

Given('I click the {string} button on the confirmation pop-up modal') do |button|
  within('.modal') do #might have to change .modal to whatever the conformation box is 
    click_button(button)
  end
end

Then('{string} should not appear on the list of attendees for information session with date {int}\/{int}\/{int} and time {int}:{int} {word}') do |name, month, day, year, hour, minute, meridian|
    dt = parse_session_datetime(month, day, year, hour, minute, meridian)
    session = InformationSession.find_by(scheduled_at: dt)
    visit information_session_path(session.id)
    expect(page).not_to have_content(name)
end

Then('the status for {string} should change from {string} to {string}') do |full_name, old_status, new_status|
    first_name, last_name = full_name.split(" ", 2)
    volunteer = Volunteer.find_by(first_name: , last_name: )
    visit volunteer_path(volunteer.id)
    expect(page).not_to have_content(old_status)
    expect(page).to have_content(new_status)
end

Given('John Smith cancels their sign up for information session with date {int}\/{int}\/{int} and time {int}:{int} {word}') do |month, day, year, hour, minute, meridian|
    dt = parse_session_datetime(month, day, year, hour, minute, meridian)
    session = InformationSession.find_by(scheduled_at: dt)
    volunteer = Volunteer.find_by(first_name: "John", last_name: "Smith")
    if session.volunteers.exists?(volunteer.id)
        session.volunteers.delete(volunteer)
    end
end

Given('I click the {string} button for information session with date {int}\/{int}\/{int} and time {int}:{int} {word}') do |button, month, day, year, hour, minute, meridian|
    dt = parse_session_datetime(month, day, year, hour, minute, meridian)
    session_time_str = dt.strftime("%B %-d, %Y %-l:%M %p")
    row = find('tr', text: session_time_str)
    row.click_button(button)
end

Then('every attendees status should change from {string} to {string}') do |old_status, new_status|
  InformationSession.all.each do |session|
    session.volunteers.each do |attendee|
      expect(attendee.status).to eq(new_status)
    end
  end
end

Given('I have changed the {string} dropdown to {string}') do |dropdown, value|
  select value, from: dropdown
end

Given('{string} has signed up for an information session with date {int}\/{int}\/{int} and time {int}:{int} {word}') do |full_name, month, day, year, hour, minute, meridian|
  dt = parse_session_datetime(month, day, year, hour, minute, meridian)
  session = InformationSession.find_by(scheduled_at: dt)
  first_name, last_name = full_name.split(" ", 2)
  volunteer = Volunteer.find_by(first_name: first_name, last_name: last_name)
  session.volunteers << volunteer unless session.volunteers.exists?(volunteer.id)
end

Given('I have left the {string} field blank') do |field|
  fill_in field, with: ''
end

Then('an information session with a blank date should not be on the list of information sessions') do
  visit information_sessions_path
  expect(page).not_to have_selector('.information-session', text: '')
end

Then('an information session with a blank date should not be on the inquiry form') do
  visit inquiry_form_path
  # Check that no sessions with a blank date are displayed
  expect(page).not_to have_selector('.information-session', text: '')
end

Then('all attendees should receive a notification email that the time for the event they are signed up for has changed to {int}:{int} {word}') do |int, int2, word|
    pending # Waiting on MailChimp
end

When('the reminder job runs') do
  pending # Waiting on Mail Chimp
end

Then('{string} should receive a reminder email about the session') do |string|
  pending # Waiting on Mail Chimp
end

Then('every attendee should receive an email notification that the event was cancelled and be prompted to sign up for a new information session') do
  pending # Waiting on mail chimp 
end