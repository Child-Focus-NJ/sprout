Given("I am on the volunteer {string} profile page") do |name|
  @volunteer = find_or_create_volunteer_by_name(name)
  visit "/volunteers/#{@volunteer.id}"
end

Given("I am on the volunteers list page") do
  visit "/volunteers"
end

Given("I am on the sign-in page for session {string}") do |session_name|
  @session = InformationSession.find_or_create_by!(name: session_name) do |s|
    s.scheduled_at = 1.month.from_now
  end
  visit "/information_sessions/#{@session.id}/sign_in"
end

When("I view the volunteer {string} profile") do |name|
  @volunteer = find_or_create_volunteer_by_name(name)
  visit "/volunteers/#{@volunteer.id}"
end

When("I view the volunteer profile") do
  visit "/volunteers/#{@volunteer.id}"
end