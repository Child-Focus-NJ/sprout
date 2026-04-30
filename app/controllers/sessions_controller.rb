class SessionsController < ApplicationController
  def new
  end

  def create
    auth = request.env["omniauth.auth"]
    unless auth
      flash[:alert] = "Authentication failed"
      return redirect_to login_path
    end

    unless User.allowed_email?(auth.info.email)
      flash[:alert] = "Must use a Child Focus NJ associated email"
      return redirect_to login_path
    end

    user = User.from_omniauth(auth)
    session[:user_id] = user.id
    redirect_to volunteers_path
  end

  def failure
    flash[:alert] = "Authentication failed"
    redirect_to login_path
  end
end
