When("I compose an email with subject {string} and message {string}") do |subject, message|
  fill_in "Subject", with: subject
  fill_in "Message", with: message
end

Then("the email history should show {string} and {string}") do |subject, message|
  within("#communications") do
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
