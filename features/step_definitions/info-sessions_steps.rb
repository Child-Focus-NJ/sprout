def format_session_datetime(month_abbr, day, year, hour, minute, meridian)
  date_str = "#{month_abbr} #{day.to_s.rjust(2, '0')}, #{year}"
  time_str = "#{hour.to_s.rjust(2, '0')}:#{minute.to_s.rjust(2, '0')} #{meridian}"
  [date_str, time_str]
end

def parse_session_datetime(month_abbr, day, year, hour, minute, meridian)
  DateTime.parse("#{month_abbr} #{day}, #{year} #{hour}:#{minute.to_s.rjust(2, '0')} #{meridian}")
end

Given('the following information sessions exist:') do |table|
    table.hashes.each do |row|
        FactoryBot.create(:information_session,
            capacity: row['capacity'],
            scheduled_at: Date.parse(row['scheduled_at']),
            name: row['name'],
            location: row['location']
        )
    end
end

Given('the following volunteers exist:') do |table|
    table.hashes.each do |row|
        Volunteer.find_or_create_by!(email: row['email']) do |volunteer|
        volunteer.first_name = row['first_name']
        volunteer.last_name  = row['last_name']
        volunteer.password = 'password123' if volunteer.respond_to?(:password)
      end
    end
end


Given('I am on the information session management page') do
    visit information_sessions_path
end

Then('I should be on the create new information session page') do
    visit new_information_session_path
end

Then(/^I have selected "(.*)" from "(.*)"$/) do |option, field|
  select option, from: field
end

Given('I have filled out the {string} field with {string}') do |field_name, value|
    fill_in field_name, with: value
end


Given('I have clicked the {string} button') do |button|
  click_on button
end

Given('I click the {string} navigation button') do |button| # use for navigation links
  click_link button
end

Then('an information session with date {word} {int}, {int} and time {int}:{int} {word} should be on the list of information sessions') do |month_abbr, day, year, hour, minute, meridian|
  date_str, time_str = format_session_datetime(month_abbr, day, year, hour, minute, meridian)
  expect(page).to have_content(date_str)
  expect(page).to have_content(time_str)
end


Then('an information session with date {word} {int}, {int} and time {int}:{int} {word} should be on the inquiry form') do |month_abbr, day, year, hour, minute, meridian|
    visit inquiry_form_path # might need to change once we implement
    date_str, time_str = format_session_datetime(month_abbr, day, year, hour, minute, meridian)
    expect(page).to have_content(date_str)
    expect(page).to have_content(time_str)
end

Then('the information session with date {word} {int}, {int} and time {int}:{int} {word} should have a Zoom link for the meeting') do |month_abbr, day, year, hour, minute, meridian|
  date_str, time_str = format_session_datetime(month_abbr, day, year, hour, minute, meridian)
  session_element = find('.information-session', text: "#{date_str} #{time_str}")

  expect(session_element).to have_link('Zoom')
end

Then('a message that says {string} will appear') do |message|
    expect(page).to have_content(message)
end

Then('an information session with date {word} {int}, {int} and time {int}:{int} {word} should not be on the list of information sessions') do |month_abbr, day, year, hour, minute, meridian|
  date_str, time_str = format_session_datetime(month_abbr, day, year, hour, minute, meridian)
  expect(page).not_to have_content(date_str)
  expect(page).not_to have_content(time_str)
end

Then('an information session with date {word} {int}, {int} and time {int}:{int} {word} should not be on the inquiry form') do |month_abbr, day, year, hour, minute, meridian|
  visit inquiry_form_path
  date_str, time_str = format_session_datetime(month_abbr, day, year, hour, minute, meridian)
  expect(page).not_to have_content(date_str)
  expect(page).not_to have_content(time_str)
end

Given('I am on the edit page for information session with date {word} {int}, {int} and time {int}:{int} {word}') do |month_abbr, day, year, hour, minute, meridian|
  dt = parse_session_datetime(month_abbr, day, year, hour, minute, meridian)
  session = InformationSession.find_by(scheduled_at: dt)
  visit edit_information_session_path(session.id)
end

Given('I edit the {string} field to be {string}') do |field_name, value|
  select value, from: field_name
end

Given('I click the {string} button') do |button|
  click_on button
end

Given('I click the {string} button for attendee with name {string}') do |button, name|
  row = find('tr', text: name)

  row.click_button(button)
end

Given('I click the {string} button on the confirmation pop-up modal') do |button|
  within('.modal') do # might have to change .modal to whatever the conformation box is
    click_button(button)
  end
end

Then('{string} should not appear on the list of attendees for information session with date {word} {int}, {int} and time {int}:{int} {word}') do |name, month_abbr, day, year, hour, minute, meridian|
  dt = parse_session_datetime(month_abbr, day, year, hour, minute, meridian)
  session = InformationSession.find_by(scheduled_at: dt)
  visit information_session_path(session.id)
  expect(page).not_to have_content(name)
end

Then('the status for {string} should change from {string} to {string}') do |full_name, old_status, new_status|
    first_name, last_name = full_name.split(" ", 2)
    volunteer = Volunteer.find_by(first_name:, last_name:)
    visit volunteer_path(volunteer.id)
    expect(page).not_to have_content(old_status)
    expect(page).to have_content(new_status)
end

Given('John Smith cancels their sign up for information session with date {word} {int}, {int} and time {int}:{int} {word}') do |month_abbr, day, year, hour, minute, meridian|
  dt = parse_session_datetime(month_abbr, day, year, hour, minute, meridian)
  session = InformationSession.find_by(scheduled_at: dt)
  volunteer = Volunteer.find_by(first_name: "John", last_name: "Smith")
  if session.volunteers.exists?(volunteer.id)
    session.volunteers.delete(volunteer)
  end
end

Given('I click the {string} button for information session with date {word} {int}, {int} and time {int}:{int} {word}') do |button, month_abbr, day, year, hour, minute, meridian|
  dt = parse_session_datetime(month_abbr, day, year, hour, minute, meridian)
  date_str, time_str = format_session_datetime(month_abbr, day, year, hour, minute, meridian)
  row = find('tr', text: date_str)
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


Given('{string} has signed up for an information session with date {word} {int}, {int} and time {int}:{int} {word}') do |full_name, month_abbr, day, year, hour, minute, meridian|
  dt = parse_session_datetime(month_abbr, day, year, hour, minute, meridian)
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
