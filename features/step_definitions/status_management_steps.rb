Given("the volunteer has status {string}") do |status|
  @volunteer.update!(current_funnel_stage: status.parameterize.underscore.to_sym)
end

Given("the volunteer was sent an application on {string}") do |date|
  @volunteer.update!(application_sent_at: Date.parse(date))
end

Given("the volunteer has already received the application email") do
  @volunteer.update!(application_sent_at: 1.day.ago)
end

When("I change the status to {string}") do |status|
  select status, from: "Status"
end

When("I press {string}") do |button|
  click_on button
end

When("I open the status change dropdown") do
  click_button "Change Status"
end

When("I attempt to send the application email again") do
  click_button "Send Application"
end

Then("the volunteer should have status {string}") do |status|
  expect(page).to have_content(status)
end

Then("I should see a status change entry for {string} to {string}") do |from_status, to_status|
  expect(page).to have_content(from_status)
  expect(page).to have_content(to_status)
end

Then("the status change should include a timestamp") do
  expect(page).to have_css("[data-timestamp]")
end

Then("I should see status option {string}") do |status|
  expect(page).to have_content(status)
end

Then("I should still see application sent date {string}") do |date|
  expect(page).to have_content(date)
end

Then("the application email should not be sent") do
  expect(page).not_to have_content("Application sent")
end

Then("I should see a message that the application was already sent") do
  expect(page).to have_content("already sent")
end

Given("the volunteer {string} is registered for this session") do |name|
  @volunteer = find_or_create_volunteer_by_name(name)
  SessionRegistration.create!(
    volunteer: @volunteer,
    information_session: @session,
    status: :registered
  )
end

When("I check in the volunteer {string}") do |name|
  @volunteer = find_or_create_volunteer_by_name(name)
  click_button "Check in #{@volunteer.full_name}"
end

Then("the volunteer's first session attended date should be set") do
  @volunteer.reload
  expect(@volunteer.first_session_attended_at).to be_present
end

Then("the volunteer's application submitted date should be set") do
  @volunteer.reload
  expect(@volunteer.application_submitted_at).to be_present
end
