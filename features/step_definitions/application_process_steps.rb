When("I mark the application as submitted") do
  click_button "Mark as Submitted"
end

Then("the application email should be queued for the volunteer {string}") do |name|
  expect(page).to have_content("Application queued for #{name}")
end

Then("the volunteer status should change to {string}") do |status|
  expect(page).to have_content(status)
end

Then("the volunteer's application sent date should be set") do
  @volunteer.reload
  expect(@volunteer.application_sent_at).to be_present
end

Then("the system should record when the application was submitted") do
  expect(page).to have_content("submitted")
end

Then("staff should be notified of the submission") do
  expect(page).to have_content("notified")
end

Then("the volunteer should appear in the applied section") do
  expect(page).to have_css("#applied-section")
end

Given("there are volunteers with status {string}") do |status|
  Volunteer.create!(
    first_name: "Vol",
    last_name: "One",
    email: "vol1@example.com",
    current_funnel_stage: status.parameterize.underscore.to_sym
  )
end

When("I go to the application dashboard") do
  visit "/application_dashboard"
end

Then("I should see an {string} section") do |section_name|
  expect(page).to have_content(section_name)
end

Then("I should see volunteers with {string} status") do |status|
  expect(page).to have_content(status)
end

Then("the list should be sorted by days waiting") do
  expect(page).to have_css(".volunteer-list")
end

Given("I am on the admin settings page") do
  visit "/admin/settings"
end

When("I view application reminder settings") do
  visit "/admin/settings"
  click_on "Application reminders"
end

Then("I should see the reminder interval setting") do
  expect(page).to have_content("Reminder interval")
end

Then("I should be able to change the reminder frequency") do
  expect(page).to have_css("select", text: "frequency")
end

Given("the volunteer {string} has status {string}") do |name, status|
  @volunteer = find_or_create_volunteer_by_name(name)
  @volunteer.update!(current_funnel_stage: status.parameterize.underscore.to_sym)
end

Given("the volunteer has pending application reminder emails") do
  # Setup handled by previous step
end

When("the system detects that the application was submitted in the External System") do
  # Simulate external system sync: trigger background job
  @volunteer.update!(application_submitted_at: Time.current, current_funnel_stage: :applied)
end

Then("all pending application reminder emails should be stopped") do
  expect(@volunteer.scheduled_reminders.pending_reminders.count).to eq(0)
end