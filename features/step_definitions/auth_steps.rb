Given("I am a signed-in system administrator") do
  @user = User.create!(
    email: "admin@example.com",
    first_name: "Admin",
    last_name: "User",
    role: :admin
  )
  visit root_path
  expect(page).to have_content("Admin Dashboard")
end
