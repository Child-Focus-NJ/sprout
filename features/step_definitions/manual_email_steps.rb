When("I compose an email with subject {string} and message {string}") do |subject, message|
  fill_in "Subject", with: subject
  fill_in "Message", with: message
end

Then("the email history should show {string} and {string}") do |subject, message|
  within(".timeline .email-entry") do
    expect(page).to have_content(subject)
    expect(page).to have_content(message)
    expect(page).to have_content("cucumber-email-id")
  end
end

When("I open application email settings from Admin") do
  click_link "Admin"
  click_link "Application email settings"
end

When("I save the application link {string}") do |url|
  fill_in "Application link", with: url
  click_button "Save application link"
  expect(page).to have_content("Application link saved.")
end

Then("the application email should contain {string}") do |url|
  expect(page).to have_content("Application email sent to Mailchimp")
  expect(@volunteer.communications.email.where(purpose: "application").last.body).to include(url)
end

Given("the application link has not been configured") do
  SystemSetting.set("application_url", "")
end

Then("no application email should be recorded") do
  expect(@volunteer.communications.email.where(purpose: "application")).to be_empty
  expect(@volunteer.reload.application_sent_at).to be_nil
end

Given("Mailchimp rejects the email") do
  @email_provider_status = "rejected"
end

Then("the email draft should retain {string} and {string}") do |subject, message|
  expect(page).to have_field("Subject", with: subject)
  expect(page).to have_field("Message", with: message)
end

# Reloads the page so the popup's template menu includes the new template
Given("an active email template named {string} with subject {string} and body {string}") do |name, subject, body|
  CommunicationTemplate.create!(name: name, subject: subject, body: body, template_type: :email,
    funnel_stage: :inquiry, trigger_type: :manual, active: true)
  visit current_url
end

When("I choose the email template {string}") do |name|
  select name, from: "Email template"
  expect(page).to have_content("Template loaded.")
end

Then("the saved email should use the template {string}") do |name|
  expect(@volunteer.communications.email.last.communication_template.name).to eq(name)
end
