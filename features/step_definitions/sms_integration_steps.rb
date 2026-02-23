Given("the volunteer has a phone number") do
  @volunteer.update!(phone: "5551234567")
end

Given("the volunteer has an invalid or unreachable phone number") do
  @volunteer.update!(phone: "000")
end

Given("the volunteer {string} has received {int} SMS messages") do |name, count|
  @volunteer = find_or_create_volunteer_by_name(name)
  count.times do |i|
    Communication.create!(
      volunteer: @volunteer,
      communication_type: :sms,
      body: "SMS message #{i + 1}",
      sent_at: (i + 1).hours.ago
    )
  end
end

Given("an SMS was sent to the volunteer {string}") do |name|
  @volunteer = find_or_create_volunteer_by_name(name)
  Communication.create!(
    volunteer: @volunteer,
    communication_type: :sms,
    body: "Test SMS",
    sent_at: 1.hour.ago
  )
end

When("I click {string}") do |text|
  click_on text
end

When("I enter the message {string}") do |message|
  fill_in "Message", with: message
end

Then("the SMS should be sent to the volunteer's phone") do
  expect(page).to have_content("SMS sent")
end

Then("I should see a confirmation message") do
  expect(page).to have_css(".alert-success, .notice, [role='alert']")
end

Then("I should see a message composition field") do
  expect(page).to have_field("Message", type: "textarea")
end

Then("I should see a character count") do
  expect(page).to have_content(/character|char\s*count/i)
end

Then("I should be able to type custom message content") do
  expect(page).to have_field("Message")
end

Then("I should see the SMS communication history") do
  expect(page).to have_content("SMS")
end

Then("each entry should show the date and time sent") do
  expect(page).to have_css(".communication-entry time")
end

Then("each entry should show the message content or preview") do
  expect(page).to have_css(".communication-entry .content")
end

When("I view the communication history for {string}") do |name|
  @volunteer = find_or_create_volunteer_by_name(name)
  visit "/volunteers/#{@volunteer.id}"
end

Then("I should see the SMS delivery status") do
  expect(page).to have_content("delivered")
end

Then("the status should be one of {string}") do |_options|
  expect(page).to have_content(/\b(queued|sent|delivered|failed)\b/)
end

Then("the system should flag the phone number as bad") do
  expect(page).to have_css(".phone-invalid, .bad-phone")
end

Then("I should see an indication that the phone number may be invalid") do
  expect(page).to have_content(/invalid|unreachable|bad/i)
end