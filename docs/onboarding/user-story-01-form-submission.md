# User Story 1: Form Submission

## Overview

Full user story definition: [`docs/user-stories/01-form-submission.md`](../user-stories/01-form-submission.md)

Allows a potential volunteer to submit an inquiry form so staff can capture their information and begin the onboarding funnel, including:
- Inquiry form submission
- Required field validation
- Confirmation after successful submission
- Walk-in inquiry flow from information session check-in

---

## Pull Requests

| Phase | PR                                                                                                                                    |
|---|---------------------------------------------------------------------------------------------------------------------------------------|
| Failing BDD | [PR #61 — Add Failing BDD Tests for User Stories 1–4](https://github.com/Child-Focus-NJ/sprout/pull/61)                               |
| Green | [PR #95 — [User Story 1 Green] Inquiry form submission and validation](https://github.com/Child-Focus-NJ/sprout/pull/95)                                                     |
| Refactor | [PR #122 — UI for user stories 1-4] Inquiry form UI cleanup and validation polish](https://github.com/Child-Focus-NJ/sprout/pull/122) |

---

## Summary of changes

| Change | Description |
|---|---|
| **Inquiry form page** | Added a styled inquiry form for collecting volunteer information |
| **Required field validation** | Validates first name, last name, email, and phone before submission |
| **Validation feedback** | Displays inline validation errors when required information is missing or invalid |
| **Successful submission flow** | Creates an `InquiryFormSubmission` record and shows a confirmation message |
| **Walk-in support** | If launched from an information session check-in flow, the form records the inquiry and connects it to that session |

---

## Relevant Files

- `app/controllers/inquiry_form_controller.rb` → Inquiry form flow and validation
- `app/views/inquiry_form/new.html.erb` → Inquiry form UI
- `app/models/inquiry_form_submission.rb` → Inquiry submission persistence
- `config/routes.rb` → Inquiry form routes
- `features/01_form_submission.feature` → BDD scenarios

---

## Step-by-step Flow

### Standard Inquiry Submission
- Staff navigates to the inquiry form
- Enters first name, last name, email, and phone
- Submits the form
- System stores the inquiry and shows a confirmation

### Validation Failure
- Staff submits the form with missing or invalid information
- Validation errors are displayed
- No inquiry is created

### Walk-in Inquiry
- Staff is redirected from session check-in for an unregistered attendee
- Staff completes the inquiry form
- Inquiry is recorded and associated with the information session

---

## Testing

```bash
docker compose up --build -d


