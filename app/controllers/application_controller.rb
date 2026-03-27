class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user

  private

  def current_user
    return @current_user if defined?(@current_user)
    # In the browser flow, we set `session[:user_id]` in `SessionsController`.
    # In Cucumber tests, `login_as(..., scope: :user)` sets Warden's current user.
    @current_user = request.env["warden"]&.user(:user) || User.find_by(id: session[:user_id])
  end
end
