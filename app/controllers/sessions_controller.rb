class SessionsController < ApplicationController
    def new
    end

    def create
        auth = request.env['omniauth.auth']

        unless auth
            flash[:alert] = "Authentication failed"
            redirect_to login_path and return
        end

        email = auth.info.email

        if email.ends_with?('@childfocusnj.org')
            session[:user_email] = email
            redirect_to volunteers_path
        else
            flash[:alert] = "Must use a Child Focus NJ associated email"
            redirect_to login_path
        end
    end
end
