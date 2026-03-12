Given('I am on the system management page') do
  visit system_management_index_path
end
Given('the following users exist:') do |table|
    table.hashes.each do |row|
        User.find_or_create_by!(email: row['email']) do |user|
        user.first_name = row['first_name']
        user.last_name  = row['last_name']
        user.password = 'password123' if volunteer.respond_to?(:password)
        user.role = row['role']
      end
    end
end


Given('{string} submits an application') do |name|
  @volunteer = find_or_create_volunteer_by_name(name)
  @volunteer.update!(
    application_sent_at: Time.current,
    current_funnel_stage: :applied
  )
end

Then('I should receive a notification that {string} data was transferred to the external system') do |volunteer|
  expect(page).to have_content("#{volunteer} data was transferred to the external system")
end

Then('the status for {string} should be {string}') do |volunteer, status|
  visit volunteer_path(user)
  expect(page).to have_content(status)
end

Then('the profile for {string} should include a note that says {string} with the time and date that it occurred') do |volunteer, note|
  visit volunteer_path(volunteer)
  expect(page).to have_content(note)
  formatted_date = Time.current.strftime("%m/%d/%Y")
  expect(page).to have_content(formatted_date)
end

Given('I click {string} for {string}') do |button, row|
  within(row) do
    click_on button
  end
end

Then('I should see {string} on the frequency list') do |frequency|
  expect(page).to have_content(frequency)
end

Then('I should not see {string} on the frequency list') do |frequency|
  expect(page).not_to have_content(frequency)
end

Given('I upload an Excel sheet containing {string}') do |volunteer|
  visit "/volunteers/upload"
  attach_file("file", filepath)
  click_button "Upload"
end

Then('{string} should appear on the volunteers page') do |volunteer|
  visit volunteer_path
  expect(page).to have_content(volunteer)
end

Given('I have clicked the {string} button for {string}') do |button, user|
  employee = User.find_by(name: user)
  within("#user_#{employee.id}") do
    click_button button
  end
end

Then('I should get a confirmation box that says {string}') do |message|
  expect(page).to have_content(message)
end

Given('I have clicked {string}') do |button|
  click_button button
end

Given('I enter {string} in the {string} field') do |title, field|
  fill_in field, with: value
end

Given('I select {string} in the {string} dropdown field') do |role, field|
  select role, from: field
end

Given('I have clicked the {string} on the confirmation modal') do |button|
  within('.modal') do
    click_button button
  end
end

Then('{string} should appear on the page') do |name|
  expect(page).to have_content(name)
end

Then('I should not see {string} on the page') do |name|
  expect(page).not_to have_content(name)
end
