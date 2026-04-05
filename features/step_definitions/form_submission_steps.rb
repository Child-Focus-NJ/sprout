Given("I am on the inquiry form page") do
  visit new_inquiry_form_path
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

Then("I should see an email required error") do
  assert_text("Email")
  assert_text("can't be blank")
end

Then("no inquiry should exist for {string}") do |email|
  email_key = email.strip.downcase
  has_raw = InquiryFormSubmission.where("raw_data ->> 'email' = ?", email_key).exists?
  assert !has_raw
end

Then("an inquiry should exist for {string}") do |email|
  inquiry = InquiryFormSubmission.where("LOWER(raw_data ->> 'email') = ?", email.strip.downcase).first
  expect(inquiry).not_to be_nil
end
