# User Story 11: Integration Admin

## Overview

Full user story definition: [`docs/user-stories/10-reporting-export.md`](../user-stories/10-reporting-export.md)

Allows system administrators to generate reports and export volunteer data, including:
- Generating a PDF bar chart report comparing information session sign-ups or applications across a date range grouped by year
- Sending a generated PDF report directly to the printer
- Exporting volunteer data as Excel, CSV, or JSON filtered by status and date range
---

## Pull Requests

| Phase | PR                                                                                                                                    |
|---|---------------------------------------------------------------------------------------------------------------------------------------|
| Failing BDD | [PR #16 — Failing BDD User Stories 10-13](https://github.com/Child-Focus-NJ/sprout/pull/16)                               |
| Green | [PR #131 — User Story 10 Green](https://github.com/Child-Focus-NJ/sprout/pull/131)                                                     |
| Refactor | [PR #141 — Refactor User Story 10](https://github.com/Child-Focus-NJ/sprout/pull/141) |

---

## Summary of Changes

| Change | Description |
|---|---|
| **PDF report export** | Admins can generate a bar chart PDF report comparing information session sign-ups or applications by year |
| **Print report** | Admins can send a generated PDF report directly to the printer |
| **Data export** | Admins can export volunteer data as Excel, CSV, or JSON with optional filtering by status and date range |

## Relevant Files

- `app/controllers/reporting_exporting_controller.rb` → Handles rendering the page, generating PDF reports, and exporting volunteer data
- `app/views/reporting_exporting/index.html.erb` → Reporting and exporting page with sections for creating reports and exporting data
- `config/routes.rb` → Routes for reporting and exporting, including `export_report` and `export_data` collection actions
- `features/reporting_exporting.feature` → Cucumber scenarios for PDF report export, print, and data export flows
- `features/step_definitions/reporting_exporting_steps.rb` → Step definitions for the reporting and exporting feature
- `spec/requests/reporting_exporting_spec.rb` → RSpec request specs for the reporting and exporting controller

---

## Step-by-step Flow

### Viewing the Reporting & Exporting Page
- Administrator navigates to the reporting and exporting page
- Sees two sections: "Create a Report" and "Export Data"

### Exporting a PDF Report
- Administrator selects an x-axis (e.g. "years") and y-axis (e.g. "information session sign-ups" or "applications")
- Fills in a start date, end date, and title
- Selects "PDF" as the report format
- Clicks "Export Report" to download a PDF bar chart to their downloads folder
- Or clicks "Print" to send the report directly to the printer

### Exporting Data
- Administrator fills in a title and selects an export format (Excel, CSV, or JSON)
- Optionally filters by volunteer status and date range
- Clicks "Export Data" to download the file to their downloads folder
- The exported file contains volunteer names, emails, and statuses matching the selected filters

---

## Testing

```bash
docker compose up --build -d
```

### RSpec

```bash
docker compose exec -e RAILS_ENV=test -e DATABASE_URL=postgres://sprout:sprout@db:5432/sprout_test web bash -lc "bin/rails db:test:prepare && bundle exec rspec spec/requests/reporting_exporting_spec.rb"
```

### Cucumber

```bash
docker compose exec -e RAILS_ENV=test -e DATABASE_URL=postgres://sprout:sprout@db:5432/sprout_test web bash -lc "bin/rails db:test:prepare && bundle exec cucumber features/reporting_exporting.feature"
```


