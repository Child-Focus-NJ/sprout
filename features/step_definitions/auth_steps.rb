 Given("I am a signed-in system administrator") do
   @user = User.find_or_create_by!(
     email: "admin@example.com",
     first_name: "Admin",
     last_name: "User",
     role: :admin
   )
   login_as(@user, scope: :user)#fixed for oauth
   visit root_path
   expect(page).to have_content("Admin Dashboard")
 end
