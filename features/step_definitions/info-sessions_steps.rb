def format_session_datetime(month_abbr, day, year, hour, minute, meridian)
  date_str = "#{month_abbr} #{day.to_s.rjust(2, '0')}, #{year}"
  time_str = "#{hour.to_s.rjust(2, '0')}:#{minute.to_s.rjust(2, '0')} #{meridian}"
  [ date_str, time_str ]
end

def parse_session_datetime(month_abbr, day, year, hour, minute, meridian)
  day = day.to_s.rjust(2, '0')    # "6" -> "06"
  hour = hour.to_s.rjust(2, '0')  # "6" -> "06"
  minute = minute.to_s.rjust(2, '0') # "0" -> "00"
  Time.zone.parse("#{month_abbr} #{day}, #{year} #{hour}:#{minute} #{meridian}")
end

Given('the following information sessions exist:') do |table|
  table.hashes.each do |row|
    unless InformationSession.exists?(name: row['name'], scheduled_at: Time.zone.parse(row['scheduled_at']))
      session = FactoryBot.build(:information_session,
        name: row['name'],
        scheduled_at: Time.zone.parse(row['scheduled_at']),
        capacity: row['capacity'],
        location: row['location']
      )
      session.save(validate: false)
    end
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
  datetime = DateTime.strptime("#{month_abbr} #{day} #{year} #{hour}:#{minute} #{meridian}", "%b %d %Y %I:%M %p")
  expected_time = datetime.strftime("%b %d, %Y %I:%M %p")
  expect(page).to have_content(expected_time)
end


Then('an information session with date {word} {int}, {int} and time {int}:{int} {word} should be on the inquiry form') do |month_abbr, day, year, hour, minute, meridian|
    visit new_inquiry_form_path
    date_str, time_str = format_session_datetime(month_abbr, day, year, hour, minute, meridian)
    expect(page).to have_content(date_str)
    expect(page).to have_content(time_str)
end

Then('the information session with date {word} {int}, {int} and time {int}:{int} {word} should have a Zoom link for the meeting') do |month_abbr, day, year, hour, minute, meridian|
  pending # waiting on Zoom
end

Then('a message that says {string} will appear') do |message|
    expect(page).to have_content(message)
end

Then('an information session with date {word} {int}, {int} and time {int}:{int} {word} should not be on the list of information sessions') do |month_abbr, day, year, hour, minute, meridian|
  datetime = DateTime.strptime("#{month_abbr} #{day} #{year} #{hour}:#{minute} #{meridian}", "%b %d %Y %I:%M %p")
  expected_time = datetime.strftime("%b %d, %Y %I:%M %p")
  expect(page).not_to have_content(expected_time)
end

Then('an information session with date {word} {int}, {int} and time {int}:{int} {word} should not be on the inquiry form') do |month_abbr, day, year, hour, minute, meridian|
  visit new_inquiry_form_path
  datetime = DateTime.strptime("#{month_abbr} #{day} #{year} #{hour}:#{minute} #{meridian}", "%b %d %Y %I:%M %p")
  expected_time = datetime.strftime("%b %d, %Y %I:%M %p")
  expect(page).not_to have_content(expected_time)
end

Given('I am on the edit page for information session with date {word} {int}, {int} and time {int}:{int} {word}') do |month_abbr, day, year, hour, minute, meridian|
  naive_time = DateTime.strptime("#{month_abbr} #{day} #{year} #{hour}:#{minute} #{meridian}", "%b %d %Y %I:%M %p")
  session = InformationSession.all.find do |s|
    s.scheduled_at.strftime("%b %d %Y %I:%M %p") == naive_time.strftime("%b %d %Y %I:%M %p")
  end

  raise "No session found at #{naive_time}" unless session

  visit edit_information_session_path(session)
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

Then('{string} should not appear on the list of attendees for information session with date {word} {int}, {int} and time {int}:{int} {word}') do |name, month_abbr, day, year, hour, minute, meridian|
  dt = parse_session_datetime(month_abbr, day, year, hour, minute, meridian)
  session = InformationSession.find_by(scheduled_at: dt)
  visit edit_information_session_path(session.id)
  expect(page).not_to have_content(name)
end

Then('the status for {string} should change from {string} to {string}') do |full_name, old_status, new_status|
    first_name, last_name = full_name.split(" ", 2)
    volunteer = Volunteer.find_by(first_name:, last_name:)
    visit volunteer_path(volunteer.id)
    expect(page).not_to have_content(old_status)
    expect(page).to have_content(new_status)
end

Given('{string} cancels their sign up for information session with date {word} {int}, {int} and time {int}:{int} {word}') do |name, month_abbr, day, year, hour, minute, meridian|
  first_name, last_name = name.split(" ", 2)
  dt = parse_session_datetime(month_abbr, day, year, hour, minute, meridian)
  session = InformationSession.find_by(scheduled_at: dt)
  volunteer = Volunteer.find_by(first_name:, last_name:)
  if session.volunteers.exists?(volunteer.id)
    session.volunteers.delete(volunteer)
  end
end

Given('I click the {string} button for information session with date {word} {int}, {int} and time {int}:{int} {word}') do |button, month_abbr, day, year, hour, minute, meridian|
  dt = parse_session_datetime(month_abbr, day, year, hour, minute, meridian)
  date_str, time_str = format_session_datetime(month_abbr, day, year, hour, minute, meridian)
  row = find('tr', text: /#{Regexp.escape(date_str)}.*#{Regexp.escape(time_str)}/)
  row.click_button(button)
end

Then('every attendees status should change from {string} to {string}') do |old_status, new_status|
  volunteers = Volunteer.joins(:session_registrations).distinct

  volunteers.each do |attendee|
    expect(attendee.reload.current_funnel_stage).to eq(new_status)
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
  visit new_inquiry_form_path
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
