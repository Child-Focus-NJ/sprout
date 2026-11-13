# Heroku Manual Deployment Notes
This short guide assumes you have no prior application/database deployed and that you are doing this to deploy a working version on Heroku

1. Download and install the [Heroku CLI](https://devcenter.heroku.com/articles/heroku-cli)
2. Create a Heroku account, if you do not already have one.
3. From the `sprout` directory, issue the following commands in this order via the command line (shell):
   1. `heroku create <appname> --addons heroku-postgresql:essential-0` - creates the application, provisions the addon PostgreSQL database, and attaches it to the application. Additionally, this will:
      * set the application's `DATABASE_URL` environment variable to provide the database details to the application, and
      * add the `heroku` remote to your local git config file (`.git/config`) to enable git pushes directly to Heroku
   2. `git push heroku <branchname>:main` - pushes the named branch to Heroku's `main` branch.
>[!NOTE]
> When changing the URL of the app, set the redirect URL of the app in Google OAuth settings. See image below.
> <p align="center">
> <img width="304" height="381" alt="Screenshot 2026-11-12 at 9 17 54 PM" src="https://github.com/user-attachments/assets/3e129ae7-076c-40ce-b98e-364375d77370" />
> </p>

>[!NOTE]
> As part of the deployment process, the database migrations should execute via the [Procfile](`Procfile`). 

   4. `heroku run "rake db:seed"` - seeds the database
   5. `heroku config:set RAILS_MASTER_KEY="$(cat config/master.key)"` - passes the value of the encryption master key to the application, so that keys used for external services (Mailchimp,
Mandrill, Google OAuth) work correctly. Thsi will restart the application to apply the variables.
