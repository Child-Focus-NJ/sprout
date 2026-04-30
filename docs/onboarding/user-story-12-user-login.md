# User Story 12: User Login

## Overview

Full user story definition: [`docs/user-stories/12-user-login.md`](../user-stories/12-user-login.md)

Allows staff and administrators to sign in to Sprout using their Google account, including:
- Google OAuth login flow
- Email domain validation to restrict access to authorized users
- Redirect to volunteer home page on successful login
- Error handling for failed or unauthorized login attempts

---

## Pull Requests

| Phase | PR                                                                                                                                    |
|---|---------------------------------------------------------------------------------------------------------------------------------------|
| Failing BDD | [PR #62 — Add Failing BDD Tests for User Stories 10-13](https://github.com/Child-Focus-NJ/sprout/pull/62)                               |
| OAuth Setup | [PR #76 — Omniauth addition](https://github.com/Child-Focus-NJ/sprout/pull/76)                               |
| Green | [PR #77 — User story 12 green cucumber](https://github.com/Child-Focus-NJ/sprout/pull/77)                                                     |
| Refactor | [PR #133 — Refactor User Story 12] (https://github.com/Child-Focus-NJ/sprout/pull/122) |

---

## Summary of changes

| Change | Description |
|---|---|
| **Login page** | Added a styled login page with a Google Sign In button |
| **Google OAuth integration** | Integrated OmniAuth Google OAuth2 for authentication |
| **Email domain validation** | Restricts access to `@passaiccountycasa.org` and `@nyu.edu` email domains |
| **User creation** | Creates a new user record on first login via `User.from_omniauth` |
| **Session management** | Sets `session[:user_id]` on successful login and clears it on logout |
| **Error handling** | Redirects to login page with an alert for failed or unauthorized attempts |

## Relevant Files

- `app/controllers/users_controller.rb` → User management (create and destroy)
- `app/controllers/sessions_controller.rb` → OAuth callback handling, session creation and destruction
- `app/views/sessions/new.html.erb` → Login page UI
- `app/models/user.rb` → User persistence
- `config/routes.rb` → Login routes
- `features/12_user_login.feature` → BDD scenarios
- `features/step_definitions/user_login_steps.rb` → Step definitions

---

## Step-by-step Flow

### Successful Login
- User navigates to the login page
- Clicks "Sign in with Google"
- Completes the Google OAuth flow with an authorized email domain
- System finds or creates the user record
- User is redirected to the volunteer home page

### Unauthorized Email
- User completes the Google OAuth flow with a non-authorized email domain
- System rejects the login attempt
- User is redirected to the login page with an error message

### Failed Authentication
- OAuth flow fails or returns no auth data
- User is redirected to the login page with an error message

---

## Testing

```bash
docker compose up --build -d
```

### RSpec

```bash
docker compose exec -e RAILS_ENV=test -e DATABASE_URL=postgres://sprout:sprout@db:5432/sprout_test web bash -lc "bin/rails db:test:prepare && bundle exec rspec spec/models/user_spec.rb"
```

### Cucumber

```bash
docker compose exec -e RAILS_ENV=test -e DATABASE_URL=postgres://sprout:sprout@db:5432/sprout_test web bash -lc "bin/rails db:test:prepare && bundle exec cucumber features/12_user_login.feature"
```


