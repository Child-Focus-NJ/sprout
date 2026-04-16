# User Story 7: SMS Integration

## Overview

Full user story definition: [`docs/user-stories/07-sms-integration.md`](../user-stories/07-sms-integration.md)

- Enables staff to send SMS messages directly to volunteers from their profile page. Messages are delivered via Mailchimp/Mandrill through an AWS Lambda integration, with a local fallback for development/testing. All messages are stored and displayed in the volunteer’s communication history with delivery tracking.

Please refer to [`docs/onboarding/mailchimp-integration.md`](../onboarding/mailchimp-integration.md) for more information.

---

## Related Pull Requests

| Phase | PR |
|---|---|
| Failing BDD | [PR #50 — Add Failing BDD Tests for User Stories 5–8](https://github.com/Child-Focus-NJ/sprout/pull/50) |
| Green | [PR #82 — [User Story 7 Green] SMS Integration](https://github.com/Child-Focus-NJ/sprout/pull/82) |
| Refactor | [PR #104 — [User Story 7 Refactor] SMS Integration Feature](https://github.com/Child-Focus-NJ/sprout/pull/104) |

---
## Summary of Changes

| Change | Description |
|---|---|
| SMS compose page | `/volunteers/:id/sms` page with message input and character counter |
| Send SMS | `POST /volunteers/:id/send_sms` sends message via service layer |
| Dual delivery mode | Mailchimp/Lambda in production, local DB-only fallback in dev/test |
| Validation | Blocks blank messages, missing phone numbers, and >320 char messages |
| SMS history | Displays all SMS communications on volunteer profile |
| Delivery tracking | Status lifecycle: `pending → sent → delivered/failed/bounced` |
| Auto timeline note | SMS sends create a `Note` entry for volunteer activity feed |
| Phone validation hint | UI warns if phone number appears invalid (<10 digits) |

---

## Relevant Files

- `app/services/sms/mailchimp_outbound.rb` → Core SMS delivery logic + validation
- `app/controllers/volunteers_controller.rb` → `sms` and `send_sms` actions
- `app/models/communication.rb` → SMS storage, status tracking, callbacks
- `app/views/volunteers/sms.html.erb` → SMS compose UI
- `app/views/volunteers/show.html.erb` → SMS history section + entry point
- `config/routes.rb` → SMS routes
- `spec/services/sms/mailchimp_outbound_spec.rb` → Service tests
- `spec/requests/volunteers_send_sms_spec.rb` → Controller tests
- `spec/models/communication_spec.rb` → Communication callbacks
- `features/07_sms_integration.feature` → BDD scenarios

---
## Step-by-Step Flow

### Compose SMS
- Staff opens volunteer profile → clicks "Send SMS"
- Navigates to `/volunteers/:id/sms`
- Enters message (max 320 chars)

---

### Send SMS Request
- `POST /volunteers/:id/send_sms`
- Calls `Sms::MailchimpOutbound.deliver!`

---

### Validation
- Rejects:
  - Blank messages
  - Messages > 320 characters
  - Missing phone number

---

### Delivery Mode

#### Local Mode (dev/test)
- Creates `Communication` record
- Immediately marked `delivered`
- Creates a `Note` entry for timeline

#### Mailchimp Mode (production)
- Sends via AWS Lambda (API Gateway)
- Stores as `pending → delivered/failed`
- Updates status after response

---

### History Display
- All SMS messages shown on volunteer profile
- Ordered by most recent first
- Includes body, timestamp, & status

---

## Testing

```bash
docker compose up --build -d
```

### RSpec

```bash
docker compose exec -e RAILS_ENV=test -e DATABASE_URL=postgres://sprout:sprout@db:5432/sprout_test -e SIMPLECOV=true web bash -lc "bin/rails db:test:prepare && bin/rails tailwindcss:build && bundle exec rspec spec/services/sms/mailchimp_outbound_spec.rb spec/requests/volunteers_send_sms_spec.rb spec/models/communication_spec.rb"
```

### Cucumber

```bash
docker compose exec -e RAILS_ENV=test -e DATABASE_URL=postgres://sprout:sprout@db:5432/sprout_test web bash -lc "bin/rails db:test:prepare && bin/rails tailwindcss:build && bundle exec cucumber features/07_sms_integration.feature"
```