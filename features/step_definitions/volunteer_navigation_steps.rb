Given("I am on the volunteer {string} profile page") do |name|
  @volunteer = find_or_create_volunteer_by_name(name)
  visit "/volunteers/#{@volunteer.id}"
end

Given("I am on the volunteers list page") do
  visit "/volunteers"
end



When("I view the volunteer {string} profile") do |name|
  @volunteer = find_or_create_volunteer_by_name(name)
  visit "/volunteers/#{@volunteer.id}"
end

When("I view the volunteer profile") do
  visit "/volunteers/#{@volunteer.id}"
end
