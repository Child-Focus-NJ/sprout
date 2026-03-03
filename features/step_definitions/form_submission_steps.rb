Given("I am on the inquiry form page") do
  visit "/inquiry_form_submissions/new"
end

When("I submit a valid inquiry for {string}") do |email|
  fill_in "Email", with: email
  click_button "Submit"
end

When("I submit an inquiry missing an email") do
  fill_in "Email", with: ""
  click_button "Submit"
end

Then("I should see a submission confirmation") do
  assert_text("Thank")
end

Then("an inquiry should exist for {string}") do |email|
  assert InquiryFormSubmission.where(email: email.strip.downcase).exists?
end

Then("I should see an email required error") do
  assert_text("Email")
  assert_text("can't be blank")
end

Then("no inquiry should exist for {string}") do |email|
  assert !InquiryFormSubmission.where(email: email.strip.downcase).exists?
end
