Given("the volunteer {string} has notes, reminders, and info session entries") do |name|
  @volunteer = find_or_create_volunteer_by_name(name)
  Note.create!(volunteer: @volunteer, content: "Test note", user: @user)
end

Given("the volunteer {string} has notes, emails, and SMS in the timeline") do |name|
  @volunteer = find_or_create_volunteer_by_name(name)
  Note.create!(volunteer: @volunteer, content: "Note", user: @user)
  Communication.create!(volunteer: @volunteer, communication_type: :email, body: "Email")
  Communication.create!(volunteer: @volunteer, communication_type: :sms, body: "SMS")
end

When("I enter {string}") do |text|
  fill_in "Note", with: text
end

Then("I should see the note {string}") do |note_text|
  expect(page).to have_content(note_text)
end

Then("the note should display a timestamp") do
  expect(page).to have_css("time, [data-timestamp]")
end

Then("the note should display who created it") do
  expect(page).to have_content(@user.full_name)
end

Then("I should see a single consolidated timeline") do
  expect(page).to have_css(".timeline, [data-timeline]")
end

Then("the timeline should include reminders, info sessions, and manual notes") do
  expect(page).to have_content("reminder")
end

Then("entries should be in chronological order") do
  expect(page).to have_css(".timeline .entry")
end

When("a reminder email or SMS is sent to the volunteer") do
  Communication.create!(
    volunteer: @volunteer,
    communication_type: :email,
    body: "Reminder",
    sent_at: Time.current,
    sent_by_user_id: @user.id
  )
end

Then("a note should be automatically created") do
  expect(@volunteer.notes.where(note_type: :communication).count).to be >= 1
end

Then("the note should indicate the type of communication sent") do
  expect(page).to have_content(/email|sms/i)
end

Then("the note should include the date and time") do
  expect(page).to have_content(/\d{1,2}\/\d{1,2}\/\d{4}|\d{1,2}:\d{2}/)
end

Then("I should see a filter by type option") do
  expect(page).to have_css("select, [data-filter], .filter")
end

When("I filter the timeline to show only notes") do
  select "Notes", from: "Filter"
end

Then("I should see only manual notes") do
  expect(page).to have_css(".note-entry")
end

Then("I should not see email or SMS entries in the filtered view") do
  expect(page).not_to have_css(".email-entry, .sms-entry")
end

When("I view the action buttons") do
  visit "/volunteers/#{@volunteer.id}"
end

Then("I should see an {string} button") do |button_name|
  expect(page).to have_button(button_name)
end

Then("I should see a {string} button for the volunteer") do |button_name|
  expect(page).to have_button(button_name)
end

Then("the Note button should be visually distinct from the Delete button") do
  expect(page).to have_button("Add Note")
  expect(page).to have_button("Delete")
end

Then("the Delete button should require confirmation") do
  expect(page).to have_css("[data-confirm], [data-method='delete']")
end

When("I select the volunteers {string} and {string}") do |name1, name2|
  v1 = find_or_create_volunteer_by_name(name1)
  v2 = find_or_create_volunteer_by_name(name2)
  check "volunteer_#{v1.id}"
  check "volunteer_#{v2.id}"
end

Then("the note should be added to both volunteers") do
  expect(page).to have_content("added to 2 volunteers")
end