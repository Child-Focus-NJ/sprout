Given('I am on the system management page') do
  visit system_management_path
end

Given('Samantha Ray attended an information session in {int}') do |year|
  volunteer = Volunteer.find_by!(first_name: 'Samantha', last_name: 'Ray')

  session_in_year = InformationSession.find_by(name: "Test Session #{year}") || begin
    s = InformationSession.new(
      name: "Test Session #{year}",
      scheduled_at: Time.zone.parse("#{year}-06-15 10:00:00"),
      capacity: 20,
      location: "415 Hamburg Turnpike"
    )
    s.save!(validate: false)
    s
  end

  registration = SessionRegistration.find_or_initialize_by(
    volunteer: volunteer,
    information_session: session_in_year
  )
  registration.status = :attended
  registration.checked_in_at = Time.zone.parse("#{year}-06-15 10:00:00")
  registration.save!

  volunteer.update_columns(first_session_attended_at: Time.zone.parse("#{year}-06-15 10:00:00"))
end

Given('Samantha Ray has status {string}') do |status_label|
  volunteer = Volunteer.find_by!(first_name: 'Samantha', last_name: 'Ray')

  case status_label
  when 'Attended an Information Session'
    volunteer.update_columns(
      first_session_attended_at: volunteer.first_session_attended_at || Time.current,
      current_funnel_stage: Volunteer.current_funnel_stages[:application_eligible]
    )
  when 'Inquiry'
    volunteer.update_columns(current_funnel_stage: Volunteer.current_funnel_stages[:inquiry])
  when 'Application Sent'
    volunteer.update_columns(current_funnel_stage: Volunteer.current_funnel_stages[:application_sent])
  when 'Applied'
    volunteer.update_columns(current_funnel_stage: Volunteer.current_funnel_stages[:applied])
  when 'Inactive'
    volunteer.update_columns(current_funnel_stage: Volunteer.current_funnel_stages[:inactive])
  else
    raise "Unknown status label: #{status_label}"
  end
end

Given('I select {string} in the {string} dropdown in the export data section') do |value, dropdown_label|
  within('#export-data-section') do
    select value, from: dropdown_label
  end
end

Given('I have filled out the {string} field with {string} in the export data section') do |field, value|
  within('#export-data-section') do
    fill_in field, with: value
  end
end

Given('I enter {string} as the title in the export data section') do |title|
  within('#export-data-section') do
    fill_in 'Title', with: title
  end
end

Then('an excel file named {string} should be in my downloads folder') do |filename|
  download_path = DownloadHelpers.downloaded_file_path("#{filename}.xlsx")
  Timeout.timeout(10) do
    sleep 0.5 until File.exist?(download_path)
  end
  expect(File).to exist(download_path)
end

Then('the excel sheet should contain {string}') do |expected_value|
  xlsx_files = Dir[File.join(DownloadHelpers::DOWNLOAD_PATH, '*.xlsx')]
  expect(xlsx_files).not_to be_empty, "No Excel file found in downloads folder"

  workbook = RubyXL::Parser.parse(xlsx_files.last)
  all_cell_values = workbook.worksheets.flat_map do |sheet|
    sheet.map { |row| row&.cells&.map { |cell| cell&.value&.to_s } }.flatten.compact
  end

  expect(all_cell_values).to include(expected_value),
    "Expected Excel to contain '#{expected_value}' but found: #{all_cell_values.first(20).inspect}"
end

Given('I click the {string} tab') do |tab|
  within(".sys-tabs") { click_link tab }
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
  visit current_url
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
  visit current_url
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

Given('a referral source named {string} exists') do |name|
  ReferralSource.find_or_create_by!(name: name) { |source| source.active = true }
end

Then('the {string} button for {string} should require confirmation') do |button, row|
  visit current_url
  href = nil
  within(:xpath, "//li[.//span[contains(@class,'volunteer-name') and contains(normalize-space(.), '#{row}')]]") do
    link = find_link(button)
    href = link[:href]
    expect(href).to match(/confirm_remove_/)
  end

  visit href
  expect(page).to have_css(".delete-confirm-inline", text: /Are you sure/i, wait: 5)
  expect(page).to have_css(".delete-confirm-inline button.btn-delete", text: /Yes/)
  expect(page).to have_link("Cancel")
end
