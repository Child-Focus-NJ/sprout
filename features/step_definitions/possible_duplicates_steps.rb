module PossibleDuplicateSteps
  # The pair on Admin > Possible Duplicates whose two names are these, in either order
  def possible_duplicate_pair(first_name, second_name)
    pair = all("#possible-duplicates .duplicate-pair").find do |card|
      card.all(".duplicate-pair__name").map(&:text).sort == [ first_name, second_name ].sort
    end
    pair || raise("No possible duplicate pair for #{first_name} and #{second_name}")
  end
end
World(PossibleDuplicateSteps)

Given("these volunteers also exist:") do |table|
  table.hashes.each do |row|
    Volunteer.create!(email: row["email"], first_name: row["first_name"], last_name: row["last_name"],
                      phone: row["phone"].presence)
  end
end

Then("the Admin link should have a red dot") do
  expect(page).to have_css(".app-navbar__links a .app-navbar__dot")
end

Then("the Admin link should not have a red dot") do
  expect(page).to have_no_css(".app-navbar__dot")
end

Then("I should see {int} possible duplicate pair(s)") do |count|
  expect(page).to have_css("#possible-duplicates .duplicate-pair", count: count)
end

Then("{string} and {string} should be listed as possible duplicates because of {string}") do |first_name, second_name, reason|
  expect(possible_duplicate_pair(first_name, second_name)).to have_css(".duplicate-pair__reason", text: reason)
end

When("I mark {string} and {string} as not a duplicate") do |first_name, second_name|
  within(possible_duplicate_pair(first_name, second_name)) { click_button "Not a duplicate" }
end

When("I open the merge popup for {string} and {string}") do |first_name, second_name|
  within(possible_duplicate_pair(first_name, second_name)) { find_button("Merge", exact: true).click }
  expect(page).to have_css("dialog.merge-dialog[open]")
end

When("I choose {string} in the merge popup") do |value|
  within("dialog.merge-dialog[open]") { choose value }
end

When("I visit {string}'s profile") do |name|
  first_name, last_name = name.split(" ", 2)
  visit volunteer_path(Volunteer.find_by!(first_name: first_name, last_name: last_name))
end

Then("the profile's contact details should be {string} and {string}") do |email, phone|
  within("#contact-info") do
    expect(page).to have_field("Email", with: email)
    expect(page).to have_field("Phone", with: phone)
  end
end
