Given("I am a signed-in system administrator") do
  @user = User.find_or_initialize_by(email: "admin@childfocusnj.org")
  @user.assign_attributes(
    first_name: "Admin",
    last_name: "User",
    role: :admin,
    google_uid: "cucumber-admin-google-uid",
    active: true
  )
  @user.save!
  login_as(@user, scope: :user)
  visit root_path
  expect(page).to have_css('img[alt="Sprout"], img[alt="Sprout logo"]')
end
