# User Story 11: Integration Admin

## Overview

Full user story definition: [`docs/user-stories/11-integration-admin.md`](../user-stories/11-integration-admin.md)

Allows system administrators to integrate with external systems and manage application settings, including:
- Receiving notifications when volunteer data is successfully transferred to an external system
- Viewing a note on the volunteer's profile with the timestamp of the data transfer
- Adding and removing reminder frequency options used throughout the system
- Adding and removing volunteer tags for categorizing volunteers
- Importing historical volunteer data from an Excel spreadsheet
- Managing employee accounts by adding new users with name, email, and role
- Removing employee accounts with an inline confirmation step
---

## Pull Requests

| Phase | PR                                                                                                                                    |
|---|---------------------------------------------------------------------------------------------------------------------------------------|
| Failing BDD | [PR #16 — Failing BDD User Stories 10-13](https://github.com/Child-Focus-NJ/sprout/pull/16)                               |
| Green | [PR #111 — User Story 11 Integration Admin Green](https://github.com/Child-Focus-NJ/sprout/pull/111)                                                     |
| Refactor | [PR #140 — Refactor User Story 11](https://github.com/Child-Focus-NJ/sprout/pull/140) |

---

## Summary of changes

| Change | Description |
|---|---|
| **Sync notifications** | Dashboard view of volunteer data transfers to the external system in the last 24 hours |
| **Transfer notes** | Automatic note added to volunteer profile with timestamp when data is transferred |
| **Volunteer status on transfer** | Volunteer status is set to Applied when data is pushed to the external system |
| **Reminder frequencies** | Admins can add and remove reminder frequency options used across the system |
| **Volunteer tags** | Admins can add and remove tags for categorizing volunteers |
| **Historical data import** | Upload an Excel spreadsheet to bulk-import volunteer records |
| **Employee management** | Admins can add new employee accounts with name, email, and role |
| **Employee removal** | Inline confirmation step before removing an employee account |

## Relevant Files

- `app/controllers/reminder_frequencies_controller.rb` → Handles creating and deleting reminder frequency options
- `app/controllers/system_management_controller.rb` → Renders the system management page and handles Excel import
- `app/controllers/users_controller.rb` → Handles creating and deleting employee accounts
- `app/controllers/volunteer_tags_controller.rb` → Handles creating and deleting volunteer tags
- `app/views/system_management/show.html.erb` → System management page with sections for frequencies, tags, import, and employees
- `config/routes.rb` → Routes for system management, reminder frequencies, volunteer tags, and users
- `features/11_integration_admin.feature` → Cucumber scenarios for all integration and administration flows
- `features/step_definitions/integration_admin_steps.rb` → Step definitions for the integration and administration feature
- `app/models/reminder_frequency.rb` → Model for reminder frequency records
- `app/models/volunteer_tag.rb` → Model for volunteer tag records
- `app/models/external_sync_log.rb` → Model for tracking volunteer data transfers to the external system
- `app/services/volunteer_import_service.rb` → Service object that parses an Excel file and bulk-creates volunteer records
- `spec/requests/system_management_spec.rb` → RSpec request specs for the system management controller
- `spec/services/volunteer_import_service_spec.rb` → RSpec unit specs for the import service

---

## Step-by-step Flow

### Volunteer Data Transfer
- A volunteer submits an application and their data is pushed to the external system
- Administrator sees a notification on the system management page confirming the transfer
- A timestamped note is automatically added to the volunteer's profile
- Volunteer's status is updated to Applied

### Managing Reminder Frequencies
- Administrator navigates to the system management page
- Clicks "Add Frequency", enters a title, and clicks "Save Frequency"
- New frequency appears on the list and is available across the system
- Administrator clicks "Remove" next to a frequency to delete it

### Managing Volunteer Tags
- Administrator navigates to the system management page
- Clicks "Add Tag", enters a title, and clicks "Save Tag"
- New tag appears on the list and can be applied to volunteers
- Administrator clicks "Remove" next to a tag to delete it

### Importing Historical Data
- Administrator clicks "Choose File" and selects an Excel spreadsheet
- Clicks "Import Data"
- Volunteers from the spreadsheet are created in the system and appear on the volunteers page

### Adding an Employee
- Administrator clicks "Add Employee" and fills in first name, last name, email, and role
- Clicks "Save Employee"
- New employee appears on the employee list and can access the system

### Removing an Employee
- Administrator clicks "Remove" next to an employee
- An inline confirmation message asks "Are you sure you want to remove this user?"
- Administrator clicks "Yes" to confirm or "Cancel" to abort
- Confirmed removal deletes the employee account and removes them from the list
---

## Testing

```bash
docker compose up --build -d
```

### RSpec

```bash
docker compose exec -e RAILS_ENV=test -e DATABASE_URL=postgres://sprout:sprout@db:5432/sprout_test web bash -lc "bin/rails db:test:prepare && bundle exec rspec spec/services/volunteer_import_service_spec.rb spec/requests/system_management_spec.rb"
```

### Cucumber

```bash
docker compose exec -e RAILS_ENV=test -e DATABASE_URL=postgres://sprout:sprout@db:5432/sprout_test web bash -lc "bin/rails db:test:prepare && bundle exec cucumber features/11_integration_admin.feature"
```


