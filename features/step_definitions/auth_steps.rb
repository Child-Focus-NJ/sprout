Given("I am a signed-in system administrator") do
  @user = User.find_or_create_by!(email: "admin@example.com") do |u|
    u.first_name = "Admin"
    u.last_name  = "User"
    u.role       = :admin
  end

  visit root_path
end
