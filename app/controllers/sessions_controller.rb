class SessionsController < ApplicationController
  def new
  end

  def create
    auth = request.env["omniauth.auth"]

    unless auth
      flash[:alert] = "Authentication failed"
      redirect_to login_path and return
    end

    email = auth.info.email

    if email && (email.end_with?("@childfocusnj.org") || email.end_with?("@nyu.edu")) # added nyu for testing
      user = User.find_or_create_by(google_uid: auth.uid) do |u|
        u.email = email
        u.first_name = auth.info.first_name || auth.info.name.split.first
        u.last_name  = auth.info.last_name || auth.info.name.split.last
      end

      session[:user_id] = user.id
      redirect_to volunteers_path
    else
      flash[:alert] = "Must use a Child Focus NJ associated email"
      redirect_to login_path
    end
  end

  def failure
    flash[:alert] = "Authentication failed"
    redirect_to login_path
  end
end
