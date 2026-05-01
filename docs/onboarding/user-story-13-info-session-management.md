# User Story 13: Information Session Management

## Overview

Full user story definition: [`docs/user-stories/13-info-session-management.md`](../user-stories/13-info-session-management.md)

Allows system administrators to create, edit, and manage information sessions, including:
- Creating in-person and Zoom information sessions with name, date/time, location, and capacity
- Validating that sessions are scheduled in the future and all required fields are present
- Editing session details including date/time changes
- Deleting sessions
- Managing attendees by removing them from a session
- Attendee cancellation flow that reverts volunteer status back to Inquiry
- Filtering sessions by date range and upcoming/past status
- Paginated list view of all information sessions
- Email notifications for session time changes, cancellations, and day-before reminders (pending MailChimp integration)
---

## Pull Requests

| Phase | PR                                                                                                                                    |
|---|---------------------------------------------------------------------------------------------------------------------------------------|
| Initial Story Creating | [PR #49 — added user story 13 and edited 1, 2, 9 based on presentation feedback](https://github.com/Child-Focus-NJ/sprout/pull/49)                               |
| Failing BDD | [PR #62 — Failing BDD User Stories 10-13](https://github.com/Child-Focus-NJ/sprout/pull/62)                               |
| Green | [PR #88 — UUser story 13 green](https://github.com/Child-Focus-NJ/sprout/pull/88)                                                     |
| Refactor | [PR #138 — Refactor User Story 13](https://github.com/Child-Focus-NJ/sprout/pull/138) |

---

## Summary of changes

| Change | Description |
|---|---|
| **Session list view** | Paginated list of all information sessions with date, time, location, and capacity |
| **Session creation** | Form to create in-person or Zoom sessions with name, date/time, location, and capacity |
| **Input validation** | Validates presence of required fields and that sessions are scheduled in the future |
| **Zoom session support** | Requires and validates a Zoom link when location is set to Zoom |
| **Session editing** | Form to edit session details including date/time and location |
| **Attendee management** | Ability to remove attendees from a session, reverting their status back to Inquiry |
| **Attendee cancellation** | Cancellation flow that removes volunteer from session and reverts funnel stage |
| **Session deletion** | Deletes a session and updates all attendee statuses |
| **Date/time filtering** | Filter sessions by start date, end date, and upcoming/past status |
| **Email notifications** | Pending MailChimp integration for time change alerts, cancellation notices, and day-before reminders |

## Relevant Files

- `app/controllers/information_sessions_controller.rb` → Handles all CRUD actions, filtering, pagination, attendee removal, and check-in logic
- `app/views/information_sessions/new.html.erb` → Form for creating a new information session
- `app/views/information_sessions/edit.html.erb` → Form for editing a session and managing its attendee list
- `app/views/information_sessions/index.html.erb` → Paginated list view of all sessions with date/location filters
- `app/views/information_sessions/sign_in.html.erb` → Check-in interface for volunteers arriving at a session
- `app/views/information_sessions/_session_fields.html.erb` → Shared form partial for session fields used by new and edit views
- `app/models/information_session.rb` → Core model with validations, scopes, callbacks, and helper methods
- `config/routes.rb` → Defines RESTful routes plus custom routes for sign-in, check-in, and attendee removal
- `features/info_session_management.feature` → Cucumber feature file covering all information session management scenarios
- `features/step_definitions/info-sessions.rb` → Step definitions for the information session Cucumber scenarios
---

## Step-by-step Flow

### Creating an In-Person Session
- Administrator navigates to the information session management page
- Clicks "Create New Information Session"
- Selects a location, fills in name, date/time, and capacity
- Clicks "Create Event"
- Session appears on the information session list

### Creating a Zoom Session
- Administrator clicks "Create New Information Session"
- Selects "Zoom" as the location
- Fills in name, date/time, capacity, and a valid Zoom link
- Clicks "Create Event"
- Session appears on the information session list

### Invalid or Missing Fields
- Administrator submits the form with a blank date or a past date
- System re-renders the form with a validation error message
- Session is not created

### Editing a Session
- Administrator navigates to the edit page for a session
- Updates the date/time or other fields
- Clicks "Save Changes"
- Changes are reflected on the session list

### Removing an Attendee
- Administrator navigates to the edit page for a session
- Clicks "Remove" next to an attendee
- Attendee is removed from the session and their status reverts to Inquiry

### Attendee Cancellation
- Volunteer cancels their sign up for a session
- They are removed from the attendee list and their status reverts to Inquiry

### Deleting a Session
- Administrator clicks "Delete" for a session on the list
- Session is removed from the list and all attendee statuses are updated

### Filtering Sessions
- Administrator enters a start and/or end date and clicks "Filter"
- List updates to show only sessions within the specified date range
- Administrator can also filter by upcoming or past sessions
---

## Testing

```bash
docker compose up --build -d
```

### RSpec

```bash
docker compose exec -e RAILS_ENV=test -e DATABASE_URL=postgres://sprout:sprout@db:5432/sprout_test web bash -lc "bin/rails db:test:prepare && bundle exec rspec spec/models/information_session_spec.rb spec/requests/information_sessions_spec.rb"
```

### Cucumber

```bash
docker compose exec -e RAILS_ENV=test -e DATABASE_URL=postgres://sprout:sprout@db:5432/sprout_test web bash -lc "bin/rails db:test:prepare && bundle exec cucumber features/13_info_session_management.feature"
```


