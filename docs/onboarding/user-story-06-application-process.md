# User Story 6: Application Process

## Overview

Full user story definition: [`docs/user-stories/06-application-process.md`](../user-stories/06-application-process.md)

Handles the lifecycle after a volunteer attends an info session:
- Application email delivery
- Tracking application submission status
- Admin dashboard for pending applications
- Configurable reminder interval
- Cancelling reminders when application is submitted

---

## Related Pull Requests

| Phase | PR |
|---|---|
| Failing BDD | [PR #50 — Add Failing BDD Tests for User Stories 5–8](https://github.com/Child-Focus-NJ/sprout/pull/50) |
| Green | [PR #78 — [User Story 6 Green] Application Process](https://github.com/Child-Focus-NJ/sprout/pull/78) |
| Refactor | [PR #100 — [User Story 6 Refactor] Application Process](https://github.com/Child-Focus-NJ/sprout/pull/100) |

---

## Summary of Changes

| Change | Description |
|---|---|
| Application email on check-in | Sends email when volunteer attends info session |
| Send application | Staff triggers application email and sets `application_sent_at` |
| Mark as submitted | Sets `application_submitted_at` and moves volunteer to `applied` |
| Application dashboard | Admin view of volunteers awaiting submission (ordered by oldest first) |
| Reminder interval setting | Admin-configurable interval stored in `SystemSetting` |
| Reminder cancellation | Pending reminders cancelled when volunteer is marked `applied` |

---

## Relevant Files

- `app/controllers/volunteers_controller.rb` → `send_application`, `mark_submitted`
- `app/controllers/application_controller.rb` → check-in flow + email trigger
- `app/controllers/application_dashboard_controller.rb` → admin dashboard listing pending applications
- `app/controllers/admin/settings_controller.rb` → reminder interval configuration
- `app/models/volunteer.rb` → application state transitions + scopes
- `app/models/system_setting.rb` → key-value settings storage
- `app/models/scheduled_reminder.rb` → reminder tracking + cancellation targets
- `app/views/application_dashboard/index.html.erb` → dashboard UI
- `app/views/admin/settings/index.html.erb` → settings UI
- `config/routes.rb` → dashboard, admin settings, application actions
- `spec/requests/application_dashboard_spec.rb` → dashboard tests
- `spec/requests/admin_settings_spec.rb` → settings tests
- `spec/requests/volunteers_status_management_spec.rb` → application endpoints
- `spec/models/volunteer_spec.rb` → core logic tests
- `features/06_application_process.feature` → BDD scenarios

---

## Step-by-Step Flow

### Check-in → Application Email
- Volunteer is checked in at info session
- System marks attendance + sets `application_eligible`
- Application email is immediately sent

---

### Send Application (Manual)
- Staff clicks "Send Application"
- Sets `application_sent_at`
- Prevents duplicate sending
- Volunteer moves to `application_sent`

---

### Mark as Submitted
- Staff clicks "Mark as Submitted"
- Sets `application_submitted_at`
- Moves volunteer to `applied`
- Cancels pending reminders

---

### Application Dashboard
- Admin views `/application_dashboard`
- Shows volunteers in `application_sent`
- Sorted by oldest first (longest waiting at top)

---

### Reminder Settings
- Admin configures reminder interval (1–12 weeks)
- Stored in `SystemSetting`
- Used for scheduling future reminders (VMS)


---

## Testing

```bash
docker compose up --build -d
```

### RSpec

```bash
docker compose exec -e RAILS_ENV=test -e DATABASE_URL=postgres://sprout:sprout@db:5432/sprout_test -e SIMPLECOV=true web bash -lc "bin/rails db:test:prepare && bin/rails tailwindcss:build && bundle exec rspec spec/models/volunteer_spec.rb spec/requests/volunteers_status_management_spec.rb spec/requests/application_dashboard_spec.rb spec/requests/admin_settings_spec.rb"
```

### Cucumber

```bash
docker compose exec -e RAILS_ENV=test -e DATABASE_URL=postgres://sprout:sprout@db:5432/sprout_test web bash -lc "bin/rails db:test:prepare && bin/rails tailwindcss:build && bundle exec cucumber features/06_application_process.feature"
```