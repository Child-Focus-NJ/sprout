Given("I am a signed-in system administrator") do
  @user = User.create!(
    email: "admin@childfocusnj.org",
    first_name: "Admin",
    last_name: "User",
    role: :admin
  )
  login_as(@user, scope: :user)
  visit root_path
  expect(page).to have_css('img[alt="Sprout"]')
end