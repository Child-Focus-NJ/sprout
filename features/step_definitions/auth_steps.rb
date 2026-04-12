Given("I am a signed-in system administrator") do
  @user = User.find_or_create_by!(email: "admin@childfocusnj.org") do |u|
    u.first_name = "Admin"
    u.last_name  = "User"
    u.role       = :admin
  end
  login_as(@user, scope: :user)
  visit root_path
  expect(page).to have_css('img[alt="Sprout"]')
end
