# User Story 2: Account Management

## Overview

Full user story definition: [`docs/user-stories/02-account-management.md`](../user-stories/02-account-management.md)

Prevents duplicate volunteer accounts and ensures inquiry submissions are matched correctly to existing records, including:
- Duplicate email detection
- Email normalization
- Reuse of an existing volunteer account when possible
- Protection against duplicate volunteer creation

---

## Pull Requests

| Phase | PR                                                                                                       |
|---|----------------------------------------------------------------------------------------------------------|
| Failing BDD | [PR #61 — Add Failing BDD Tests for User Stories 1–4](https://github.com/Child-Focus-NJ/sprout/pull/61)  |
| Green | [PR #101 — [User Story 2 Green] Duplicate volunteer prevention and normalized email matching](https://github.com/Child-Focus-NJ/sprout/pull/101) |
| Refactor | [PR #122 — UI for user stories 1-4] Inquiry form UI cleanup and validation polish](https://github.com/Child-Focus-NJ/sprout/pull/122) |

---

## Summary of changes

| Change | Description |
|---|---|
| **Duplicate email detection** | Prevents creating a second volunteer when the submitted email already exists |
| **Email normalization** | Trims whitespace and normalizes case before checking for duplicates |
| **Existing volunteer reuse** | Inquiry submission flow checks for an existing volunteer before creating a new record |
| **Duplicate feedback** | Displays a message when a volunteer has already signed up |

---

## Relevant Files

- `app/controllers/inquiry_form_controller.rb` → Duplicate checking and normalized email handling
- `app/models/volunteer.rb` → Volunteer records used for duplicate detection
- `app/views/inquiry_form/new.html.erb` → Inquiry submission UI
- `features/02_account_management.feature` → BDD scenarios

---

## Step-by-step Flow

### Duplicate Volunteer Prevention
- Staff submits an inquiry for an email that already exists
- System checks for an existing volunteer record
- No second volunteer is created
- Staff sees a duplicate signup message

### Normalized Email Match
- Staff submits an email with extra spaces or different capitalization
- System normalizes the email
- Existing volunteer is matched successfully
- No duplicate account is created

---

## Testing

```bash
docker compose up --build -d
```

[//]: # (### RSpec)

[//]: # ()
[//]: # (```bash)

[//]: # (docker compose exec -e RAILS_ENV=test -e DATABASE_URL=postgres://sprout:sprout@db:5432/sprout_test -e SIMPLECOV=true web bash -lc "bin/rails db:test:prepare && bin/rspec-account-management")

[//]: # (```)

### Cucumber

```bash
docker compose exec -e RAILS_ENV=test -e DATABASE_URL=postgres://sprout:sprout@db:5432/sprout_test web bash -lc "bin/rails db:test:prepare && bundle exec cucumber features/02_account_management.feature"
```