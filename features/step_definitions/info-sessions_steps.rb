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
  pending # Write code here that turns the phrase above into concrete actions
end

Given('I am on the information session management page') do
  pending # Write code here that turns the phrase above into concrete actions
end

Given('I am on the create new information session page') do
  pending # Write code here that turns the phrase above into concrete actions
end

Given('I have filled out the {string} field with {string}') do |string, string2|
  pending # Write code here that turns the phrase above into concrete actions
end

Given('I have clicked the {string} button') do |string|
  pending # Write code here that turns the phrase above into concrete actions
end

Then('I should be on the information session management page') do
  pending # Write code here that turns the phrase above into concrete actions
end

Then('an information session with date {int}/{int}/{int} and time {int}:{int} {word} should be on the list of information sessions') do |month, day, year, hour, minute, meridian|
    dt = parse_session_datetime(month, day, year, hour, minute, meridian)
    
    expect(page).to have_content(dt.strftime("%m/%d/%Y %I:%M %p"))
end

Then('an information session with date {int}/{int}/{int} and time {int}:{int} {word} should be on the inquiry form') do |month, day, year, hour, minute, meridian|
    visit inquiry_form_path unless current_path == inquiry_form_path # might need to change once we implement
    dt = parse_session_datetime(month, day, year, hour, minute, meridian)

    expect(page).to have_content(dt.strftime("%m/%d/%Y %I:%M %p"))
end

Then('the information session with date {int}/{int}/{int} and time {int}:{int} {word} should have a Zoom link for the meeting') do |month, day, year, hour, minute, meridian|
    dt = parse_session_datetime(month, day, year, hour, minute, meridian)
    session_time_str = dt.strftime("%m/%d/%Y %I:%M %p")
    session_element = find('.information-session', text: session_time_str)

    expect(session_element).to have_link('Zoom') # might need to change when implemented
end

Then('a message that says {string} will appear') do |string|
  pending # Write code here that turns the phrase above into concrete actions
end

Then('an information session with date {string} and time {int}:{int} AM should not be on the list of information sessions') do |string, int, int2|
    pending # Write code here that turns the phrase above into concrete actions
end

Then('an information session with date {string} and time {int}:{int} AM should not be on the inquiry form') do |string, int, int2|
    pending
end

Given('I am on the edit page for information session with date {int}\/{int}\/{int} and time {int}:{int} PM') do |int, int2, int3, int4, int5|
    pending
end

Given('I edit the {string} field to be {string}') do |string, string2|
  pending # Write code here that turns the phrase above into concrete actions
end

Given('I click the {string} button') do |string|
  pending # Write code here that turns the phrase above into concrete actions
end

Then('an information session with date {int}\/{int}\/{int} and time {int}:{int} PM should be on the list of information sessions') do |int, int2, int3, int4, int5|
    pending
end

Then('an information session with date {int}\/{int}\/{int} and time {int}:{int} PM should be on the inquiry form') do |int, int2, int3, int4, int5|
    pending
end

Then('an information session with date {int}\/{int}\/{int} and time {int}:{int} PM should not be on the list of information sessions') do |int, int2, int3, int4, int5|
    pending
end

Then('an information session with date {int}\/{int}\/{int} and time {int}:{int} PM should not be on the inquiry form') do |int, int2, int3, int4, int5|
    pending
end

Then('all attendees should receive a notification email that the time for the event they are signed up for has changed to {int}:{int} PM') do |int, int2|
    pending
end

Given('I click the {string} button for attendee with name {string}') do |string, string2|
  pending # Write code here that turns the phrase above into concrete actions
end

Given('I click the {string} button on the confirmation pop-up modal') do |string|
  pending # Write code here that turns the phrase above into concrete actions
end

Then('{string} should not appear on the list of attendees for information session with date {int}\/{int}\/{int} and time {int}:{int} PM') do |string, int, int2, int3, int4, int5|
    pending
end

Then('the status for {string} should change from {string} to {string}') do |string, string2, string3|
  pending # Write code here that turns the phrase above into concrete actions
end

Then('{string} does not appear on the attendance sheet for information session with date {int}\/{int}\/{int} and time {int}:{int} PM') do |string, int, int2, int3, int4, int5|
    pending
end

Given('John Smith cancels their sign up for information session with date {int}\/{int}\/{int} and time {int}:{int} PM') do |int, int2, int3, int4, int5|
    pending
end

Given('I click the {string} button for information session with date {int}\/{int}\/{int} and time {int}:{int} PM') do |string, int, int2, int3, int4, int5|
    pending
end

Then('every attendee should receive an email notification that the event was cancelled and be prompted to sign up for a new information session') do
  pending # Write code here that turns the phrase above into concrete actions
end

Then('every attendees status should change from {string} to {string}') do |string, string2|
  pending # Write code here that turns the phrase above into concrete actions
end

Given('I have changed the {string} dropdown to {string}') do |string, string2|
  pending # Write code here that turns the phrase above into concrete actions
end

Given('{string} has signed up for an information session with date {int}\/{int}\/{int} and time {int}:{int} PM') do |string, int, int2, int3, int4, int5|
    pending
end

When('the reminder job runs') do
  pending # Write code here that turns the phrase above into concrete actions
end

Then('{string} should receive a reminder email about the session') do |string|
  pending # Write code here that turns the phrase above into concrete actions
end

Given('the following flights exist:') do |table|
  # table is a Cucumber::MultilineArgument::DataTable
  pending # Write code here that turns the phrase above into concrete actions
end

Given('I am on the flights page') do
  pending # Write code here that turns the phrase above into concrete actions
end

Then('I should see {string}') do |string|
  pending # Write code here that turns the phrase above into concrete actions
end