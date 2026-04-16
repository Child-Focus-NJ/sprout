# User Story 8: Notes & Communication Tracking

## Overview

Full user story definition: [`docs/user-stories/08-notes-tracking.md`](../user-stories/08-notes-tracking.md)

Adds a unified system for tracking volunteer activity through notes and communications, including:
- Manual staff notes on volunteer profiles
- Bulk notes from the volunteers list
- Automatic notes from SMS/email sends
- A consolidated activity timeline with filtering

---

## Related Pull Requests

| Phase | PR |
|---|---|
| Failing BDD | [PR #50 — Add Failing BDD Tests for User Stories 5–8](https://github.com/Child-Focus-NJ/sprout/pull/50) |
| Green | [PR #83 — [User Story 8 Green] Notes and Communication Tracking](https://github.com/Child-Focus-NJ/sprout/pull/83) |
| Refactor | [PR #108 — [User Story 8 Refactor] Notes Tracking](https://github.com/Child-Focus-NJ/sprout/pull/108) |

---

## Summary of Changes

| Change | Description |
|---|---|
| Add note | Staff can add notes on a volunteer profile |
| Bulk notes | Add same note to multiple volunteers from list view |
| Auto notes | SMS/email sends automatically create notes |
| Activity timeline | Unified view of notes + communications + activity |
| Timeline filtering | Toggle between "All activity" and "Notes only" |

---

## Relevant Files

- `app/models/note.rb` → Note model and validation (1000 char limit)
- `app/models/volunteer.rb` → `add_staff_note` helper methods
- `app/models/communication.rb` → Auto note creation on sends
- `app/controllers/volunteers_controller.rb` → `add_note`, `bulk_add_note`
- `app/services/volunteer_timeline.rb` → Builds unified timeline
- `app/views/volunteers/show.html.erb` → Notes UI + timeline
- `app/views/volunteers/index.html.erb` → Bulk note UI
- `config/routes.rb` → note endpoints
- `spec/requests/volunteers_notes_spec.rb` → request tests
- `spec/services/volunteer_timeline_spec.rb` → timeline logic tests
- `spec/models/communication_spec.rb` → auto-note behavior
- `features/08_notes_tracking.feature` → BDD scenarios

---
## Step-by-Step Flow

### Add Note (Single Volunteer)
- Staff enters note on profile page
- Submits form
- Note saved with user who made that note + timestamp

---

### Bulk Add Notes
- Staff selects multiple volunteers in list view
- Enters note once
- Same note is applied to all selected volunteers

---

### Auto Notes (Communication Events)
- SMS/email sent by staff
- System automatically creates a `communication` note
- Appears in timeline

---

### Activity Timeline
- Profile shows combined feed of:
  - Notes
  - Communications (SMS/email)
  - Session activity
  - Scheduled reminders
- Sorted newest-first

---

### Timeline Filtering
- "All activity" shows everything
- "Notes only" shows only notes

---

## Testing

```bash
docker compose up --build -d
```

### RSpec

```bash
docker compose exec -e RAILS_ENV=test -e DATABASE_URL=postgres://sprout:sprout@db:5432/sprout_test -e SIMPLECOV=true web bash -lc "bin/rails db:test:prepare && bin/rails tailwindcss:build && bundle exec rspec spec/requests/volunteers_notes_spec.rb spec/models/volunteer_spec.rb spec/models/communication_spec.rb spec/services/volunteer_timeline_spec.rb"
```

### Cucumber

```bash
docker compose exec -e RAILS_ENV=test -e DATABASE_URL=postgres://sprout:sprout@db:5432/sprout_test web bash -lc "bin/rails db:test:prepare && bin/rails tailwindcss:build && bundle exec cucumber features/08_notes_tracking.feature"
```