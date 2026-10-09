Given("these volunteers are on the list:") do |table|
  table.hashes.each do |row|
    find_or_create_volunteer_by_name(row["name"]).update!(phone: row["phone"].presence, current_funnel_stage: row["status"])
  end
end

Given("there are {int} more volunteers on the list") do |count|
  count.times do |index|
    Volunteer.create!(first_name: "Extra", last_name: "Volunteer #{index}", email: "extra#{index}@childfocusnj.org")
  end
end

When("I visit the volunteers list") do
  visit volunteers_path
end

When("I select {string} on the list") do |name|
  check "volunteer_#{find_or_create_volunteer_by_name(name).id}"
end

When("I select all volunteers") do
  check "select-all-volunteers"
end

When("I clear the selection") do
  within("#bulk-toolbar") { click_on "Clear" }
end

When("I click {string} in the bulk toolbar") do |label|
  within("#bulk-toolbar") { click_on label }
end

# Send Application asks the browser to confirm before it moves anyone to "Application sent"
When("I send the application to the selected volunteers") do
  accept_confirm { within("#bulk-toolbar") { click_on "Send Application" } }
end

Then("the bulk toolbar should be hidden") do
  expect(page).to have_no_css("#bulk-toolbar")
end

Then("the bulk toolbar should show {string}") do |text|
  expect(find("#bulk-toolbar")).to have_text(text, normalize_ws: true)
end

# Sticky to the bottom of the screen, so it's in view even with the end of the list far below
Then("the bulk toolbar should be on screen") do
  toolbar = find("#bulk-toolbar")
  in_view = toolbar.evaluate_script(<<~JS)
    (function (el) {
      const box = el.getBoundingClientRect();
      return box.top >= 0 && box.bottom <= window.innerHeight;
    })(this)
  JS
  expect(page.evaluate_script("document.documentElement.scrollHeight > window.innerHeight")).to be(true)
  expect(in_view).to be(true)
end

Then("the popup should say {string}") do |text|
  expect(find("#message-dialog")).to have_text(text)
end

Then("{string} should be at status {string}") do |name, status|
  expect(find_or_create_volunteer_by_name(name).reload.current_funnel_stage).to eq(status)
end
