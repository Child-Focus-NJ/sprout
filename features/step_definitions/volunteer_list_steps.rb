Given("the volunteers list contains:") do |table|
  table.hashes.each do |row|
    first_name, last_name = row["name"].split(" ", 2)
    Volunteer.create!(
      first_name: first_name,
      last_name: last_name,
      email: "#{row['name'].parameterize}@childfocusnj.org",
      current_funnel_stage: row["status"],
      nj_county: NjCounty.find_or_create_by!(name: row["county"])
    )
  end
end

Given("I am on the volunteers list page filtered to status {string}") do |label|
  visit volunteers_path(status: VolunteersHelper::STATUS_BADGE_LABELS.key(label))
end

When("I search volunteers for {string}") do |query|
  fill_in "Search by name", with: query
  find_field("Search by name").send_keys(:enter)
end

When("I open the volunteer filters") do
  find(".volunteer-filter-menu__toggle").click
end

When("I choose the status {string} and the county {string}") do |status, county|
  within(".volunteer-filter-menu__panel") do
    choose status
    choose county
  end
end

When("I apply the volunteer filters") do
  within(".volunteer-filter-menu__panel") { click_button "Apply" }
end

When("I click outside the volunteer filter popup") do
  find("h1", text: "Volunteers").click
end

Then("I should see only these volunteers in the list: {string}") do |names|
  expected = names.split(",").map(&:strip)
  expect(page).to have_css("#volunteer-list .volunteer-name", count: expected.size)
  expect(all("#volunteer-list .volunteer-name").map(&:text)).to match_array(expected)
end

Then("I should see all {int} volunteers in the list") do |count|
  expect(page).to have_css("#volunteer-list .volunteer-name", count: count)
  expect(page).not_to have_css("#volunteer-count")
end

Then("the filter button should show {int} active filters") do |count|
  expect(page).to have_css(".volunteer-filter-menu__badge", text: count.to_s)
end

Then("the volunteer filter popup should be open") do
  expect(page).to have_css(".volunteer-filter-menu__panel", visible: :visible)
end

Then("the volunteer filter popup should be closed") do
  expect(page).to have_no_css(".volunteer-filter-menu__panel", visible: :visible)
end
