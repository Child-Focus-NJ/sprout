require "test_helper"

class WelcomeControllerTest < ActionDispatch::IntegrationTest
  test "root redirects to login when not signed in" do
    get root_url
    assert_redirected_to login_path
  end
end
