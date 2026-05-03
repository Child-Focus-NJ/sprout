Given('I am on the system management page') do
  visit system_management_path
end

Given('the following users exist:') do |table|
  table.hashes.each do |row|
    User.create!(email: row['email']) do |user|
      user.first_name = row['first_name']
      user.last_name  = row['last_name']
      user.password   = 'password123' if user.respond_to?(:password)
      user.role       = row['role']
    end
  end
end

Given('the following reminder frequencies exist:') do |table|
  table.hashes.each do |row|
    ReminderFrequency.create!(title: row['title'])
  end
end

Given('the following volunteer tags exist:') do |table|
  table.hashes.each do |row|
    VolunteerTag.create!(title: row['title'])
  end
end

Given('{string} submits an application') do |name|
  @volunteer = find_or_create_volunteer_by_name(name)
  @volunteer.update!(
    application_sent_at: Time.current,
    current_funnel_stage: :applied
  )
  system_user = User.first
  @volunteer.notes.create!(
    content: "Data transferred to external system",
    note_type: :system,
    user: system_user
  )
  ExternalSyncLog.create!(
    volunteer: @volunteer,
    status: :completed,
    sync_type: :push,
    sync_direction: :outbound,
    started_at: Time.current,
    completed_at: Time.current,
    records_processed: 1
  )
end


Then('I should receive a notification that {string} data was transferred to the external system') do |name|
  visit system_management_path
  expect(page).to have_content("#{name} data was transferred to the external system")
end

Then('the status for {string} should be {string}') do |name, status|
  @volunteer ||= find_or_create_volunteer_by_name(name)
  visit volunteer_path(@volunteer)
  expect(page).to have_content(status)
end

Then('the profile for {string} should include a note that says {string} with the time and date that it occurred') do |name, note|
  @volunteer ||= find_or_create_volunteer_by_name(name)
  visit volunteer_path(@volunteer)
  expect(page).to have_content(note)
  formatted_date = Time.current.strftime("%m/%d/%Y")
  expect(page).to have_content(formatted_date)
end

Given('I click {string} for {string}') do |button, row|
  visit current_path
  within(:xpath, "//li[.//span[contains(text(), '#{row}')]]") do
    click_on button
  end
end

Then('I should see {string} on the frequency list') do |text|
  expect(page).to have_content(text)
end

Then('I should not see {string} on the frequency list') do |text|
  expect(page).not_to have_content(text)
end

Given('I upload an Excel sheet containing {string}') do |name|
  first_name, last_name = name.split(' ')
  filepath = Rails.root.join('tmp', "import_#{first_name}_#{last_name}.xlsx")

  workbook = RubyXL::Workbook.new
  worksheet = workbook[0]
  worksheet.add_cell(0, 0, 'first_name')
  worksheet.add_cell(0, 1, 'last_name')
  worksheet.add_cell(0, 2, 'email')
  worksheet.add_cell(1, 0, first_name)
  worksheet.add_cell(1, 1, last_name)
  worksheet.add_cell(1, 2, "#{first_name.downcase}.#{last_name.downcase}@import.test")
  workbook.write(filepath)

  attach_file('import_file', filepath, make_visible: true)
  click_button 'Import Data'
end

Then('{string} should appear on the volunteers page') do |name|
  expect(page).to have_content('Import complete')
  visit volunteers_path
  expect(page).to have_content(name)
end

Given('I have clicked the {string} button for {string}') do |button, full_name|
  visit current_path
  first_name, last_name = full_name.split(' ')
  employee = User.find_by(first_name: first_name, last_name: last_name)
  within("#user_#{employee.id}") do
    click_on button
  end
end

Then('I should get a confirmation box that says {string}') do |message|
  expect(page).to have_content(message, wait: 5)
end

Given('I have clicked {string}') do |button|
  click_button button
end

Given('I enter {string} in the {string} field') do |value, field|
  fill_in field, with: value
end

Given('I select {string} in the {string} dropdown field') do |option, field|
  select option, from: field
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
  expect(page).to have_no_content(name, wait: 5)
end
