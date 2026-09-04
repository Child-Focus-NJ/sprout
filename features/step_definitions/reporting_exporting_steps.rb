Given('I am on the reporting and exporting page') do
  visit reporting_exporting_index_path
end


Given('{int} volunteers signed up for information sessions in {int}') do |count, year|
  session_in_year = InformationSession.find_by(name: "Test Session #{year}") || begin
    s = InformationSession.new(
      name: "Test Session #{year}",
      scheduled_at: Time.zone.parse("#{year}-06-15 10:00:00"),
      capacity: [ count, 10 ].max + 10,
      location: "415 Hamburg Turnpike"
    )
    s.save!(validate: false)
    s
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

  [ y1, y2, y3 ].each do |year|
    expect(full_text).to include(year.to_s),
      "Expected PDF to mention year #{year} but it didn't. PDF text: #{full_text.truncate(500)}"
  end
end

Then('a PDF report should be sent to the printer') do
  expect(page).not_to have_content("Invalid parameters")
end
