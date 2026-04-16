# User Story 9: Sign-In & Attendance

## Overview

Full user story definition: [`docs/user-stories/09-signin-attendance.md`](../user-stories/09-signin-attendance.md)

Implements a sign-in system for information sessions with:
- One-click check-in for registered volunteers
- Walk-in check-in via email
- Walk-in inquiry flow for new/unregistered volunteers
- Automatic attendance tracking and funnel progression
- Application email trigger on first attendance
- Duplicate check-in protection

---

## Related Pull Requests

| Phase | PR |
|---|---|
| Green | [PR #84 — [User Story 9 Green] Sign-in Attendance](https://github.com/Child-Focus-NJ/sprout/pull/84) |
| Refactor | [PR #109 — [User Story 9 Refactor] Sign-in Attendance](https://github.com/Child-Focus-NJ/sprout/pull/109) |

---
## Summary of changes

| Change | Description |
|---|---|
| **Sign-in page** | Page showing registered volunteers + walk-in email form |
| **Pre-registered check-in** | One-click check-in updates attendance + funnel stage |
| **Walk-in email check-in** | Email lookup triggers check-in or redirect to inquiry |
| **Walk-in inquiry flow** | Creates volunteer + inquiry submission if needed |
| **Attendance tracking** | Stores `checked_in_at` and `first_session_attended_at` |
| **Status transition** | Check-in moves volunteer to `application_eligible` |
| **Duplicate prevention** | Prevents re-checking in already attended volunteers |
---

## Relevant Files

- `app/controllers/information_sessions_controller.rb` → sign-in + check-in actions
- `app/controllers/inquiry_form_controller.rb` → walk-in inquiry flow
- `app/controllers/application_controller.rb` → shared check-in orchestration + email delivery
- `app/models/volunteer.rb` → `finalize_check_in_for_session!`
- `app/models/session_registration.rb` → session attendance tracking
- `app/models/inquiry_form_submission.rb` → walk-in records
- `app/views/information_sessions/sign_in.html.erb` → sign-in UI
- `app/views/inquiry_form/new.html.erb` → inquiry form
- `config/routes.rb` → sign-in + inquiry routes
- `spec/requests/information_sessions_sign_in_spec.rb` → sign-in flows
- `spec/requests/inquiry_form_walk_in_spec.rb` → walk-in flows
- `spec/models/volunteer_spec.rb` → check-in logic tests
- `features/09_sign_in_attendance.feature` → BDD scenarios

---

## Step-by-Step Flow

### Pre-registered volunteer check-in

- Staff opens session sign-in page
- Clicks “Check in”
- System:
  - Creates/updates `SessionRegistration`
  - Sets `checked_in_at`
  - Sets `first_session_attended_at` (if first time)
  - Moves volunteer to `application_eligible`
  - Sends application email
- Redirects to volunteer profile

---

### Walk-in (existing volunteer)

- Staff enters email
- If registered → check-in proceeds
- If already attended → no duplicate action
- If not registered → redirected to inquiry form

---

### Walk-in (new volunteer)

- Staff redirected to inquiry form
- Volunteer + inquiry record created
- Check-in completed immediately
- Application email queued

---

### Duplicate check-in

- If already marked `attended`
- System redirects without changes or email resend

---

## Testing

```bash
docker compose up --build -d
```

### RSpec

```bash
docker compose exec -e RAILS_ENV=test -e DATABASE_URL=postgres://sprout:sprout@db:5432/sprout_test -e SIMPLECOV=true web bash -lc "bin/rails db:test:prepare && bin/rails tailwindcss:build && bundle exec rspec spec/requests/information_sessions_sign_in_spec.rb spec/requests/inquiry_form_walk_in_spec.rb spec/models/volunteer_spec.rb"
```

### Cucumber

```bash
docker compose exec -e RAILS_ENV=test -e DATABASE_URL=postgres://sprout:sprout@db:5432/sprout_test web bash -lc "bin/rails db:test:prepare && bin/rails tailwindcss:build && bundle exec cucumber features/09_sign_in_attendance.feature"
```