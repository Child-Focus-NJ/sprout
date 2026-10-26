# Reload the profile too, since the Send SMS button is greyed out until there's a phone number
Given("the volunteer has a phone number") do
  @volunteer.update!(phone: "5551234567")
  visit volunteer_path(@volunteer)
end

Given("the volunteer {string} has a phone number") do |name|
  @volunteer = find_or_create_volunteer_by_name(name)
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
      sent_at: (i + 1).hours.ago,
      status: :sent
    )
  end
end

Given("an SMS was sent to the volunteer {string}") do |name|
  @volunteer = find_or_create_volunteer_by_name(name)
  Communication.create!(
    volunteer: @volunteer,
    communication_type: :sms,
    body: "Test SMS",
    sent_at: 1.hour.ago,
    status: :sent
  )
end

When("I click {string}") do |text|
  click_on text
end

When("I enter the message {string}") do |message|
  fill_in "Message", with: message
end

Then("the SMS should be sent to the volunteer's phone") do
  expect(page).to have_content("SMS sent to Mailchimp")
  expect(@volunteer.communications.sms.last.external_id).to eq("cucumber-sms-id")
end

When("I select the volunteer's one-time SMS consent") do
  select "One informational message", from: "SMS consent provided by the volunteer"
end

Then("I should see a confirmation message") do
  expect(page).to have_css(".flash-banner--notice, .alert-success, .notice, [role='alert'], [role='status']")
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
  expect(page).to have_css(".timeline .sms-entry time")
end

Then("each entry should show the message content or preview") do
  expect(page).to have_css(".timeline .sms-entry .content")
end

When("I view the communication history for {string}") do |name|
  @volunteer = find_or_create_volunteer_by_name(name)
  visit "/volunteers/#{@volunteer.id}"
end

Then("I should see the SMS delivery status") do
  expect(page).to have_css(".delivery-status", text: "sent")
end

Then('the status should be one of {string}, {string}, {string}, or {string}') do |s1, s2, s3, s4|
  statuses = [ s1, s2, s3, s4 ].map(&:downcase)
  expect(page).to have_content(/\b(#{Regexp.union(statuses)})\b/i)
end

Then("the system should flag the phone number as bad") do
  expect(page).to have_css(".phone-invalid, .bad-phone")
end

Then("I should see an indication that the phone number may be invalid") do
  expect(page).to have_content(/invalid|unreachable|bad/i)
end

Then("the {string} button should be disabled") do |label|
  expect(page).to have_button(label, disabled: true)
end

Then("the SMS tab in the popup should be disabled") do
  within("#message-dialog") do
    expect(page).to have_button("SMS", disabled: true)
    expect(page).to have_content("No phone number on file")
  end
end

When("I click {string} for {string} on the list") do |label, name|
  volunteer = find_or_create_volunteer_by_name(name)
  within(find(".volunteer-row", text: volunteer.full_name)) { click_on label }
end

Then("I should be on the volunteers list page") do
  expect(page).to have_current_path(volunteers_path)
end
Given("an active SMS template named {string} says {string}") do |name, body|
  CommunicationTemplate.create!(name: name, body: body, template_type: :sms,
    funnel_stage: :inquiry, trigger_type: :manual, active: true)
end

When("I open the volunteer named {string} from the list") do |name|
  @volunteer = find_or_create_volunteer_by_name(name)
  within(find(".volunteer-row", text: name)) { click_link name }
end

When("I choose the SMS template {string}") do |name|
  select name, from: "SMS template"
  expect(page).to have_content("Template loaded.")
end

Then("the message draft should be {string}") do |body|
  expect(page).to have_field("Message", with: body)
end

Then("the saved SMS should say {string} and use template {string}") do |body, name|
  communication = @volunteer.communications.sms.last
  expect(communication.body).to eq(body)
  expect(communication.communication_template.name).to eq(name)
  expect(page).to have_content(body)
end

Then("the SMS composer should link to the Mailchimp dashboards in new tabs") do
  expect(page).to have_link("Open Mailchimp dashboard", href: "https://login.mailchimp.com/", target: "_blank")
  expect(page).to have_link("View Mandrill activity", href: "https://mandrillapp.com/activity", target: "_blank")
end

When("I close the message dialog") do
  find("#message-dialog [data-message-dialog-close]").click
end

Then("the SMS template and consent should be blank") do
  expect(find("[data-sms-template-picker]").value).to eq("")
  expect(find("#dialog-sms-consent").value).to eq("")
end

Then("the SMS for {string} should say {string}") do |name, body|
  volunteer = find_or_create_volunteer_by_name(name)
  expect(volunteer.communications.sms.last).to have_attributes(body: body, status: "sent")
end
