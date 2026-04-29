Given("a volunteer exists with email {string}") do |email|
  Volunteer.create!(email: email.strip.downcase) do |v|
    v.first_name = "Existing"
    v.last_name  = "Volunteer"
  end
end

Then("there should still be only {int} volunteer with email {string}") do |count, email|
  assert_equal count, Volunteer.where(email: email.strip.downcase).count
end

Then("I should see a duplicate email message") do
  expect(page).to have_text(/already|taken|duplicate/i)
end
