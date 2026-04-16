# User Story 5: Status Management

## Overview

Full user story definition: [`docs/user-stories/05-status-management.md`](../user-stories/05-status-management.md)

Manages a volunteer’s progression through funnel stages (inquiry → applied), including:
- Manual status updates by staff
- Automatic transitions (session attendance, application submission)
- Audit logging of all changes
- Prevention of duplicate application sends

---

## Pull Requests

| Phase | PR |
|---|---|
| Failing BDD | [PR #50 — Add Failing BDD Tests for User Stories 5–8](https://github.com/Child-Focus-NJ/sprout/pull/50) |
| Green | [PR #71 — [User Story 5 Green] Status management with manual updates, automatic transitions, & audit logging](https://github.com/Child-Focus-NJ/sprout/pull/71) |
| Refactor | [PR #96 — [User Story 5 Refactor] Status management with manual updates, automatic transitions, & audit logging](https://github.com/Child-Focus-NJ/sprout/pull/96) |
| Refactor | [PR #97 — [User Story 5 Refactor] Status management refactor](https://github.com/Child-Focus-NJ/sprout/pull/97) |

---

## Summary of changes

| Change | Description |
|---|---|
| **Funnel stage enum** | `Volunteer#current_funnel_stage` stores the stage as an integer-backed enum: `inquiry`, `application_eligible`, `application_sent`, `applied`, `inactive` |
| **Manual status change** | Staff can change the stage that the volunteer is in from a dropdown on the volunteer profile and press "Update status" |
| **Automatic status change** | When a volunteer is checked in to an info session, the stage moves to `application_eligible` with trigger `:event`. When an application is marked submitted, it moves to `applied` |
| **Audit log** | Every call to `Volunteer#change_status!` creates a `StatusChange` record with `from_funnel_stage`, `to_funnel_stage`, `trigger`, `user`, and `created_at` |
| **Duplicate application-send prevention** | `Volunteer#record_application_sent!` returns `false` if `application_sent_at` is already set, so the application email cannot be sent twice |
| **Inactive volunteers retain data** | Changing a volunteer to `inactive` does not clear `application_sent_at`; the view continues to display the sent date |

---

## Relevant Files

- `app/models/volunteer.rb` → Core status logic and transitions
- `app/models/status_change.rb` → Audit trail model
- `app/controllers/volunteers_controller.rb` → Status-related actions
- `app/views/volunteers/_status_management.html.erb` → Status UI on profile page
- `config/routes.rb` → Member routes for status actions
- `spec/models/volunteer_spec.rb` → Unit tests
- `spec/requests/volunteers_status_management_spec.rb` → Request tests
- `features/05_status_management.feature` → BDD scenarios

---

## Step-by-step Flow

### Manual Status Update
- Staff selects a new stage on volunteer profile
- `change_status!` updates enum
- Creates `StatusChange` audit record

### Session Attendance (Auto)
- Check-in triggers status update to `application_eligible`
- Logged with `trigger: event`

### Send Application
- Sets `application_sent_at`
- Prevents duplicate sends

### Mark as Submitted
- Sets `application_submitted_at`
- Updates status to `applied`
- Cancels pending reminders

---

## Testing

```bash
docker compose up --build -d
```

### RSpec

```bash
docker compose exec -e RAILS_ENV=test -e DATABASE_URL=postgres://sprout:sprout@db:5432/sprout_test -e SIMPLECOV=true web bash -lc "bin/rails db:test:prepare && bin/rspec-volunteer-status"
```

### Cucumber

```bash
docker compose exec -e RAILS_ENV=test -e DATABASE_URL=postgres://sprout:sprout@db:5432/sprout_test web bash -lc "bin/rails db:test:prepare && bundle exec cucumber features/05_status_management.feature"
```