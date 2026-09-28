Given("the dashboard has volunteers in these stages:") do |table|
  table.hashes.each do |row|
    first_name, last_name = row["name"].split(" ", 2)
    Volunteer.create!(
      first_name: first_name,
      last_name: last_name,
      email: "#{row['name'].parameterize}@childfocusnj.org",
      current_funnel_stage: row["status"],
      application_sent_at: (2.days.ago if row["status"] == "application_sent")
    )
  end
end

When("I visit the dashboard") do
  visit application_dashboard_path
end

Then("the {string} tile should show {int}") do |label, value|
  tile = find(".stat-tile", text: label)
  expect(tile.find(".stat-tile__value")).to have_text(value.to_s, exact: true)
end

# Chartkick swaps each chart's placeholder for a <canvas> once Chart.js has loaded
# through importmap, so a canvas means the charts actually drew.
Then("the inquiries per month chart should be drawn") do
  expect(page).to have_css("#inquiries-by-month-chart canvas")
end

Then("the volunteers by stage chart should be drawn") do
  expect(page).to have_css("#volunteers-by-stage-chart canvas")
end
