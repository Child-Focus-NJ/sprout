# potentially would change things on this page based on oauth

Given('I am on the login page') do
  visit login_path
end

Given('I have a Child Focus NJ email domain') do
  stub_google_oauth(email: "admin@childfocusnj.org")
end

Then('I am redirected to the volunteer home page') do
  expect(page).to have_current_path(volunteers_path)
end

Given('I do not have a Child Focus NJ email domain') do
  stub_google_oauth(email: "admin@gmail.org")
end

When('I complete the Google OAuth flow as a Child Focus user') do
  stub_google_oauth(email: "admin@childfocusnj.org")
  user = User.find_or_create_by!(email: "admin@childfocusnj.org") do |u|
    u.first_name = "Admin"
    u.last_name = "User"
    u.role = :admin
    u.google_uid = "test-google-uid"
  end
  login_as(user, scope: :user)
  visit volunteers_path
end

When('I attempt Google OAuth with a non-allowed email') do
  stub_google_oauth(email: "admin@gmail.org")
  visit "/auth/google_oauth2/callback"
end

Then('I should see a rejected Google OAuth outcome') do
  expect(page).to have_content(/Must use a Child Focus NJ associated email|Authentication failed/)
end

Then('I will receive the message {string}') do |message|
  expect(page).to have_content(message)
end

Then('I will be on the login page') do
  expect(page).to have_current_path(login_path)
end
