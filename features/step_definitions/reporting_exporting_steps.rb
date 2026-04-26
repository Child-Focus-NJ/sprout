Given('I am on the reporting and exporting page') do
  visit reporting_exporting_index_path
end


Given('{int} volunteers signed up for information sessions in {int}') do |count, year|
  session_in_year = InformationSession.find_or_initialize_by(name: "Test Session #{year}")
  unless session_in_year.persisted?
    session_in_year.assign_attributes(
      scheduled_at: Time.zone.parse("#{year}-06-15 10:00:00"),
      capacity: [count, 10].max + 10,
      location: "415 Hamburg Turnpike"
    )
    session_in_year.save(validate: false)
  end

  existing_count = session_in_year.session_registrations.count
  needed = count - existing_count

  needed.times do |i|
    volunteer = Volunteer.create!(
      first_name: "Vol#{year}",
      last_name: "#{i + existing_count}",
      email: "vol#{year}_#{i + existing_count}_#{SecureRandom.hex(4)}@example.com"
    )
    SessionRegistration.create!(
      volunteer: volunteer,
      information_session: session_in_year,
      status: :registered
    )
  end
end

Given('Samantha Ray attended an information session in {int}') do |year|
  volunteer = Volunteer.find_by!(first_name: 'Samantha', last_name: 'Ray')

  session_in_year = InformationSession.find_or_initialize_by(name: "Test Session #{year}")
  unless session_in_year.persisted?
    session_in_year.assign_attributes(
      scheduled_at: Time.zone.parse("#{year}-06-15 10:00:00"),
      capacity: 20,
      location: "415 Hamburg Turnpike"
    )
    session_in_year.save(validate: false)
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

Given('I select {string} in the {string} dropdown in the create a report section') do |value, dropdown_label|
  within('#create-report-section') do
    select value, from: dropdown_label
  end
end

Given('I have filled out the {string} field with {string} in the create a report section') do |field, value|
  within('#create-report-section') do
    fill_in field, with: value
  end
end

Given('I enter {string} as the title in the create a report section') do |title|
  within('#create-report-section') do
    fill_in 'Title', with: title
  end
  if page.has_css?('#export-data-section input[name="Title"]')
    within('#export-data-section') do
      fill_in 'Title', with: title
    end
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


Then('a PDF named {string} should be in my downloads folder') do |filename|
  download_path = DownloadHelpers.downloaded_file_path("#{filename}.pdf")
  Timeout.timeout(10) do
    sleep 0.5 until File.exist?(download_path)
  end
  expect(File).to exist(download_path)
end


Then('the PDF should contain a bar chart with the years {int}, {int}, and {int} on the x-axis') do |y1, y2, y3|
  pdf_files = Dir[File.join(DownloadHelpers::DOWNLOAD_PATH, '*.pdf')]
  expect(pdf_files).not_to be_empty, "No PDF found in downloads folder"

  reader = PDF::Reader.new(pdf_files.last)
  full_text = reader.pages.map(&:text).join(' ')

  [y1, y2, y3].each do |year|
    expect(full_text).to include(year.to_s),
      "Expected PDF to mention year #{year} but it didn't. PDF text: #{full_text.truncate(500)}"
  end
end

Then('a PDF report should be sent to the printer') do
  expect(page).not_to have_content("Invalid parameters")
end

Then('an excel file named {string} should be in my downloads folder') do |filename|
  download_path = DownloadHelpers.downloaded_file_path("#{filename}.xlsx")
  expect(File).to exist(download_path),
    "Expected #{filename}.xlsx to exist in downloads but it was not found"
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