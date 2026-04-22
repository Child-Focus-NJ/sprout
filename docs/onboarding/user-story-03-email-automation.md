# User Story 3: Email Automation

## Overview

Full user story definition: [`docs/user-stories/03-email-automation.md`](../user-stories/03-email-automation.md)

Sends automated email communication based on inquiry activity so staff do not need to manually follow up, including:
- Confirmation email after a valid inquiry
- No email sent for invalid submissions
- Integration between inquiry submission and mailer delivery

---

## Pull Requests

| Phase | PR                                                                                                      |
|---|---------------------------------------------------------------------------------------------------------|
| Failing BDD | [PR #61 — Add Failing BDD Tests for User Stories 1–4](https://github.com/Child-Focus-NJ/sprout/pull/61) |
| Green | [PR #102 — [User Story 3 Green] Automated inquiry confirmation emails](https://github.com/Child-Focus-NJ/sprout/pull/102)                       |
| Refactor | [PR #122 — UI for user stories 1-4] Inquiry form UI cleanup and validation polish](https://github.com/Child-Focus-NJ/sprout/pull/122) |

---

## Summary of changes

| Change | Description |
|---|---|
| **Inquiry confirmation email** | Sends a confirmation email after a successful inquiry submission |
| **Mailer integration** | Connects the inquiry form flow to the inquiry mailer |
| **Invalid submission protection** | Prevents email delivery when form validation fails |
| **Automated communication** | Removes the need for staff to manually send inquiry confirmation messages |

---

## Relevant Files

- `app/controllers/inquiry_form_controller.rb` → Triggers email delivery after successful submission
- `app/mailers/inquiry_mailer.rb` → Inquiry confirmation mailer
- `features/03_email_automation.feature` → BDD scenarios

---

## Step-by-step Flow

### Valid Inquiry
- Staff submits a valid inquiry form
- Inquiry is recorded
- Confirmation email is sent to the submitted email address

### Invalid Inquiry
- Staff submits a form missing required data
- Validation errors are shown
- No email is sent

---

## Testing

```bash
docker compose up --build -d