Given("I clear all sent emails") do
  Communication.email.delete_all
end

Then("an email should be sent to {string}") do |to_email|
  expect(page).to have_content("Thanks! Your inquiry has been submitted.")
  expect(Communication.email.sent.where(email_to: to_email.downcase)).to exist
end

Then("no email should be sent") do
  expect(Communication.email).to be_empty
end
