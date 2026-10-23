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

When("I click the {string} status tab") do |label|
  within("#volunteer-status-tabs") { click_link label }
end

Then("I should see only these volunteers in the list: {string}") do |names|
  expected = names.split(",").map(&:strip)
  expect(page).to have_css("#volunteer-list .volunteer-name", count: expected.size)
  expect(all("#volunteer-list .volunteer-name").map(&:text)).to match_array(expected)
end

Then("I should see all {int} volunteers in the list") do |count|
  expect(page).to have_css("#volunteer-list .volunteer-name", count: count)
end

Then("the {string} status tab should be selected with {int} volunteers") do |label, count|
  expect(page).to have_css("#volunteer-status-tabs a[aria-current='page']", exact_text: "#{label} #{count}", normalize_ws: true)
end
