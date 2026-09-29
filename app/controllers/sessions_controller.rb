class SessionsController < ApplicationController
  def new
  end

  def create
    auth = request.env["omniauth.auth"]
    unless auth
      flash[:alert] = "Authentication failed"
      return redirect_to login_path
    end

    user = User.from_omniauth(auth)
    unless user
      flash[:alert] = "Your account has not been granted access to Sprout. Contact an administrator to be added."
      return redirect_to login_path
    end

    reset_session
    session[:user_id] = user.id
    redirect_to application_dashboard_path
  end

  def failure
    flash[:alert] = "Authentication failed"
    redirect_to login_path
  end

  def destroy
    request.env["warden"]&.logout
    reset_session
    redirect_to login_path, notice: "You have been logged out."
  end
end
