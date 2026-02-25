# Given("I am a signed-in system administrator") do
#   @user = User.create!(
#     email: "admin@example.com",
#     first_name: "Admin",
#     last_name: "User",
#     role: :admin
#   )
#   visit root_path
#   expect(page).to have_content("Admin Dashboard")
# end

#fixed for oauth
Given("I am a signed-in system administrator") do
  mock_auth_hash(email: "admin@casapassaicunion.org.com")
  visit user_google_oauth2_omniauth_authorize_path
  expect(page).to have_content("Admin Dashboard")
end