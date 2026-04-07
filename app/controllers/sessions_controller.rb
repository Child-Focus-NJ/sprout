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
      name_parts = auth.info.name.to_s.split
      first_from_name = name_parts.first
      last_from_name = name_parts.length > 1 ? name_parts[1..].join(" ") : nil

      user = User.find_or_create_by(google_uid: auth.uid) do |u|
        u.email = email
        u.first_name = auth.info.first_name.presence || first_from_name
        u.last_name = auth.info.last_name.presence || last_from_name
        u.avatar_url = auth.info.image.presence
      end

      user.update!(
        first_name: auth.info.first_name.presence || first_from_name || user.first_name,
        last_name: auth.info.last_name.presence || last_from_name || user.last_name,
        avatar_url: auth.info.image.presence || user.avatar_url
      )

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
