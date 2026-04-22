# User Story 4: Email Templates

## Overview

Full user story definition: [`docs/user-stories/04-email-templates.md`](../user-stories/04-email-templates.md)

Provides an admin-facing interface for managing reusable communication templates so staff can send consistent messaging, including:
- Template creation
- Template listing
- Template detail view
- Preview with sample personalization data

---

## Pull Requests

| Phase | PR                                                                                                      |
|---|---------------------------------------------------------------------------------------------------------|
| Failing BDD | [PR #61 — Add Failing BDD Tests for User Stories 1–4](https://github.com/Child-Focus-NJ/sprout/pull/61) |
| Green | [PR #103 — [User Story 4 Green] Email template management and preview](https://github.com/Child-Focus-NJ/sprout/pull/103)                       |
| Refactor | [PR #122 — UI for user stories 1-4] Inquiry form UI cleanup and validation polish](https://github.com/Child-Focus-NJ/sprout/pull/122) |

---

## Summary of changes

| Change | Description |
|---|---|
| **Template index** | Added an admin page for listing communication templates |
| **Template creation** | Added a form for creating new email templates |
| **Template details** | Added a detail page for viewing template metadata and content |
| **Template preview** | Added a preview flow that replaces `{{first_name}}` with sample input data |
| **Navigation access** | Added Email Templates to the main navigation for admin users |
| **Consistent UI** | Styled the email template pages to match the rest of the application design system |

---

## Relevant Files

- `app/controllers/admin/communication_templates_controller.rb` → Template creation, listing, show, and preview logic
- `app/models/communication_template.rb` → Template data model
- `app/views/admin/communication_templates/index.html.erb` → Template list page
- `app/views/admin/communication_templates/new.html.erb` → New template page
- `app/views/admin/communication_templates/show.html.erb` → Template detail page
- `app/views/admin/communication_templates/preview.html.erb` → Template preview page
- `app/views/admin/communication_templates/_form.html.erb` → Shared form partial
- `app/views/shared/_main_navigation.html.erb` → Navigation link for templates
- `config/routes.rb` → Admin communication template routes
- `features/04_email_templates.feature` → BDD scenarios

---

## Step-by-step Flow

### Create Template
- Admin navigates to Email Templates
- Clicks “New Template”
- Enters template name, subject, body, and metadata
- Clicks “Create”
- New template appears in the template list

### View Template
- Admin opens a template from the templates list
- System displays subject, body, and template metadata

### Preview Template
- Admin clicks preview for a template
- Enters a sample first name
- System renders personalized subject and body output

---

## Testing

```bash
docker compose up --build -d