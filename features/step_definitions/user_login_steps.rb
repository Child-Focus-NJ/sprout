# potentially would change things on this page based on oauth

Given('I am on the login page') do
  visit root_path
end

Given('I have a Child Focus NJ email domain') do
  mock_auth_hash(email: "admin@childfocusnj.org")
end

Then('I am redirected to the volunteer home page') do
  expect(page).to have_current_path(volunteer_home_path)
end

Given('I do not have a Child Focus NJ email domain') do
  mock_auth_hash(email: "admin@childfocusnj.org")
end

Then('I will receive the message {string}') do |message|
  expect(page).to have_content(message)
end

Then('I will be on the login page') do
  expect(page).to have_current_path(root_path)
end
