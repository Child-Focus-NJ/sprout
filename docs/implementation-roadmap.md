# Implementation Roadmap

This document breaks the 11 user stories into a phased implementation plan. Each phase builds on the previous one, with the most foundational and high-value work first.

---

## Phase Overview

| Phase | Name | User Stories | Priority | Estimated Effort |
|-------|------|-------------|----------|-----------------|
| **1** | Foundation | — | Critical | Medium |
| **2** | Volunteer Management | 01, 02, 05 | Critical | Large |
| **3** | Information Sessions | 09 | High | Medium |
| **4** | Email System | 03, 04 | High | Large |
| **5** | Application Process | 06 | High | Medium |
| **6** | Notes & Communication Tracking | 08 | Medium | Small |
| **7** | SMS Integration | 07 | Medium | Medium |
| **8** | Reporting & Export | 10 | Medium | Medium |
| **9** | External Integrations & Admin | 11 | Lower | Large |

---

## Phase 1: Foundation

**Goal:** Authentication, authorization, admin layout, and development tooling. Nothing user-facing works without this.

**Dependencies:** None — this is the starting point.

### Tasks

1. **Install and configure Tailwind CSS**
   - `bundle add tailwindcss-rails && rails tailwindcss:install`
   - Set up admin layout with navigation, sidebar, flash messages
   - Create shared partials: `_navbar`, `_sidebar`, `_flash`

2. **Set up authentication**
   - `bin/rails generate authentication`
   - Add `bcrypt` gem, run migrations
   - Create login page with email/password
   - Set up `Current.user` pattern
   - Add `require_authentication` to `ApplicationController`

3. **Set up Google OAuth**
   - Add `omniauth-google-oauth2` and `omniauth-rails_csrf_protection`
   - Configure Google Cloud Console credentials
   - Create OmniAuth initializer with domain restriction
   - Add callback route and handler
   - Add "Sign in with Google" button to login page

4. **Set up role-based authorization**
   - Add `require_admin`, `require_staff_or_admin` helpers
   - Create role-aware navigation (show/hide based on role)
   - Test all three roles

5. **Create seed data**
   - Seed admin user account
   - Seed referral sources
   - Seed sample system settings
   - Optionally: seed sample volunteers for development

6. **Set up Pagy and Ransack**
   - Add gems, create initializers
   - Configure Pagy with Turbo integration

### Deliverable
Staff can log in via Google or email/password. Admin layout renders with navigation. Authorization enforces role access. Development has seed data.

---

## Phase 2: Volunteer Management Core

**Goal:** CRUD for volunteers, public inquiry form, duplicate detection, status management. This is the heart of the system.

**Dependencies:** Phase 1 (auth, layout, Pagy/Ransack)

**User Stories Covered:** 01 (Form Submission), 02 (Account Management), 05 (Status Management)

### Tasks

1. **Volunteer list view (admin)**
   - `VolunteersController#index` with Ransack filtering and Pagy pagination
   - Turbo Frame for filter/sort without full page reload
   - Filter by: funnel stage, date range, referral source
   - Sort by: name, date, status
   - Color-coded status badges

2. **Volunteer detail view (admin)**
   - `VolunteersController#show`
   - Profile card with contact info, funnel stage, key dates
   - Timeline of status changes (from StatusChange model)
   - Communication history
   - Notes section
   - Quick-action buttons (change status, send email, add note)

3. **Volunteer create/edit (admin)**
   - `VolunteersController#new/create/edit/update`
   - Form with validation
   - Referral source selection (with "person" option that shows referrer fields)
   - Duplicate detection on save (check email, then name+phone)

4. **Public inquiry form**
   - `Public::InquiriesController` (no auth required)
   - Form fields: first name, last name, email, referral source, event name
   - Invisible Captcha honeypot + Rack::Attack rate limiting
   - Stores as `InquiryFormSubmission`
   - `ProcessInquiryJob` creates/links Volunteer record
   - Sends notification email to Sarah
   - Duplicate detection by email

5. **Status management**
   - FunnelProgressionService: encapsulates stage transition logic
   - Automatic status updates when events occur (attendance, application sent, etc.)
   - Manual status override by admin
   - StatusChange audit log on every transition (who, when, from, to)
   - Prevent duplicate application sends

6. **Account linking**
   - When inquiry email differs from application email, link accounts
   - UI to manually link/unlink accounts
   - Propagate referrer info when referral source is a person

### Deliverable
Staff can view, create, edit, and filter volunteers. Public visitors can submit inquiry forms. Status changes are tracked with full audit trail. Duplicate accounts are detected and linkable.

---

## Phase 3: Information Sessions & Attendance

**Goal:** Session management, Zoom-based automated attendance for virtual sessions, and manual sign-in for in-person sessions.

**Dependencies:** Phase 2 (volunteers exist in system)

**User Stories Covered:** 09 (Sign-in & Attendance)

### Tasks

1. **Information session CRUD**
   - `InformationSessionsController` with list, create, edit, delete
   - Fields: title, date/time, location, capacity, session type (virtual/in-person)
   - For virtual sessions: Zoom meeting ID, join URL fields
   - Calendar-style or list view of upcoming sessions

2. **Session registration**
   - Register volunteers for upcoming sessions
   - Registration status tracking (registered, attended, no-show, cancelled)
   - Volunteer can be registered from their profile or from the session page

3. **Zoom attendance sync (virtual sessions)**
   - `Zoom::AttendanceSyncJob` runs 20 minutes after a virtual session's scheduled end time
   - Calls Zoom Reports API (`/report/meetings/{meetingId}/participants`)
   - Matches participant emails to registered volunteers
   - Auto-marks matched volunteers as "attended"
   - Unmatched participants stored for manual review
   - Admin notified with sync summary (matched X, unmatched Y)
   - Admin review UI: list of unmatched Zoom participants with "Link to Volunteer" action

4. **Zoom attendance CSV upload (fallback)**
   - "Upload Attendance" button on session page
   - Staff downloads CSV from Zoom portal, uploads to Sprout
   - `Zoom::CsvAttendanceProcessor` parses CSV, matches by email then by name
   - Same matching/review flow as API sync
   - Works as primary method before API integration is built, and as fallback after

5. **Manual sign-in interface (in-person sessions)**
   - Tablet-friendly sign-in page for in-person info sessions
   - Large buttons, simple interface
   - Volunteer searches by name or email, taps to "Check In"
   - "Walk-in" button to add someone not pre-registered
   - Real-time attendee count

6. **Attendance triggers (shared by all methods)**
   - On attendance confirmed (Zoom sync, CSV upload, or manual check-in):
     - Update SessionRegistration status to "attended"
     - Update Volunteer funnel stage to `application_eligible`
     - Record `first_session_attended_at`
     - Stop automated follow-up emails for this volunteer
     - Trigger application email (Phase 5)
     - Create StatusChange audit record
     - Create Note: "Attended info session: [name] on [date]"

### Deliverable
Staff can create info sessions (virtual or in-person), register volunteers, and track attendance three ways: automated Zoom sync, CSV upload, or tablet sign-in. All three methods trigger the same downstream automations.

---

## Phase 4: Email Templates & Automation

**Goal:** Configurable email templates, automated sending at intervals, tracking.

**Dependencies:** Phase 2 (volunteers), Phase 3 (attendance triggers)

**User Stories Covered:** 03 (Email Automation), 04 (Email Templates)

### Tasks

1. **Configure email service**
   - Set up Postmark (or SendGrid) with ActionMailer
   - Configure production credentials via `rails credentials:edit`
   - Create `VolunteerMailer` with base template

2. **Email template management (admin)**
   - `CommunicationTemplatesController` CRUD
   - ActionText/Trix editor for template body
   - Liquid variable insertion: `{{first_name}}`, `{{session_date}}`, etc.
   - Variable cheat sheet shown alongside editor
   - Preview functionality (render template with sample data)
   - Templates organized by: funnel stage, trigger type, interval

3. **Template types**
   - Interval-based: 2 weeks, 4 weeks, 8 weeks, 12 weeks after inquiry
   - Event-triggered: attendance confirmation, application sent, session reminder
   - Special occasion: configurable seasonal templates
   - Each template linked to a funnel stage and trigger type

4. **Automated email scheduling**
   - `ProcessScheduledRemindersJob` runs every 5 minutes via Solid Queue recurring
   - On new inquiry: create ScheduledReminder records for 2/4/8/12 week intervals
   - On attendance: cancel all pending reminders, send application email
   - On skip/cancel: send "schedule another session" template
   - Track `sent_at` on each Communication record

5. **Email sending and tracking**
   - `SendReminderJob` sends individual emails
   - Records each send as a Communication (linked to volunteer and template)
   - Stores external message ID for tracking
   - Handle bounces/failures gracefully

6. **Manual email sending**
   - From volunteer profile: select template, preview, send
   - Bulk send: select multiple volunteers, choose template, confirm and send
   - "Send 4 week follow-up" quick action from volunteer list

### Deliverable
Admins can create/edit email templates with WYSIWYG editor and Liquid variables. System automatically sends follow-up emails at configured intervals. All emails tracked in communication history. Manual and bulk sending supported.

---

## Phase 5: Application Process

**Goal:** Automate application sending, track submissions, send reminders.

**Dependencies:** Phase 3 (attendance triggers), Phase 4 (email system)

**User Stories Covered:** 06 (Application Process)

### Tasks

1. **Application email automation**
   - On attendance confirmation → automatically send application email
   - Update volunteer status to `application_sent`
   - Record `application_sent_at` timestamp
   - Prevent duplicate application sends

2. **Application tracking**
   - Admin can mark application as submitted (manual or via webhook)
   - Status changes to `applied`
   - Record `application_submitted_at`
   - Volunteer moves to "applied" section in list view

3. **Application reminders**
   - For volunteers with `application_sent` status who haven't submitted
   - Configurable reminder frequency (admin setting)
   - Create ScheduledReminder records for application follow-up
   - Stop reminders when application is submitted

4. **Application dashboard section**
   - Filter volunteers by: application sent (awaiting), application submitted
   - Show days since application was sent
   - Quick action to resend application or send reminder

### Deliverable
Application email automatically sent after attendance. System tracks submission status and sends configurable reminders. Admins have clear visibility into the application pipeline.

---

## Phase 6: Notes & Communication Tracking

**Goal:** Staff can add notes to volunteer profiles, see full communication history.

**Dependencies:** Phase 2 (volunteer profiles), Phase 4 (email tracking)

**User Stories Covered:** 08 (Notes & Communication Tracking)

### Tasks

1. **Notes interface**
   - Add note form on volunteer profile (Turbo Frame for inline add)
   - Fields: content, note type (manual, system-generated)
   - Auto-populated: timestamp, creator (Current.user)
   - Chronological display with search/filter

2. **Automatic note creation**
   - When email sent → create note: "Sent: [template name]"
   - When SMS sent → create note: "SMS: [content preview]"
   - When status changes → create note: "Status changed from X to Y"
   - Note includes communication type and timestamp

3. **Bulk note actions**
   - From volunteer list: select multiple, add same note to all
   - Quick action: "Send 4 week follow-up" adds note + sends email
   - Clearly separated Note button vs Delete button in UI

4. **Communication timeline**
   - Unified timeline on volunteer profile: notes + emails + SMS + status changes
   - Filter by type
   - Searchable

### Deliverable
Full communication history visible on every volunteer profile. Notes added manually or automatically. Bulk note actions from list view.

---

## Phase 7: SMS Integration

**Goal:** Send SMS reminders via Twilio, track delivery.

**Dependencies:** Phase 4 (communication infrastructure), Phase 6 (notes)

**User Stories Covered:** 07 (SMS Integration)

### Tasks

1. **Twilio setup**
   - Configure Twilio credentials
   - Purchase phone number
   - Apply for Twilio.org Impact Access (nonprofit program)

2. **SMS sending**
   - `SendSmsJob` using twilio-ruby
   - Manual send from volunteer profile
   - Template-based SMS with Liquid variables
   - Delivery status tracking via Twilio webhooks

3. **Automated SMS scheduling**
   - Same ScheduledReminder system as email, with `communication_type: :sms`
   - Configurable intervals by admin
   - Respect preferred contact method (email vs SMS)

4. **SMS history**
   - SMS recorded as Communication records
   - Visible in volunteer profile timeline
   - Delivery status updates via Twilio status callbacks
   - Inbound SMS responses stored (if Twilio webhook configured)

### Deliverable
Staff can send SMS manually or automatically. SMS history tracked alongside email. Delivery status visible. Twilio nonprofit pricing applied.

---

## Phase 8: Reporting & Data Export

**Goal:** PDF reports, analytics dashboard, CSV/Excel export.

**Dependencies:** Phase 2 (volunteer data), Phase 3 (session data), Phase 4 (email data)

**User Stories Covered:** 10 (Reporting & Data Export)

### Tasks

1. **Analytics dashboard**
   - Chartkick charts: signups over time, funnel conversion, session attendance
   - Year-over-year comparison
   - Key metrics: total inquiries, active volunteers, conversion rate
   - Filter by date range

2. **PDF report generation**
   - Grover renders existing HTML views as PDF
   - Reports: annual summary, monthly activity, funnel analysis
   - Print-specific CSS with `@media print`
   - Download button on report pages

3. **Data export**
   - CSV export from volunteer list (with current filters applied)
   - Excel export via `caxlsx` gem or CSV (Excel opens CSV)
   - Exportable fields: all volunteer data, communication history, status history
   - Date range and status filters on export

4. **Scheduled reports (optional)**
   - Weekly summary email to admin
   - Monthly PDF report auto-generated

### Deliverable
Analytics dashboard with charts. PDF reports for printing. CSV export with filters.

---

## Phase 9: External Integrations & Administration

**Goal:** External system sync, data import, webhook handling, admin settings.

**Dependencies:** Phase 2 (volunteers), Phase 5 (application process)

**User Stories Covered:** 11 (Integration & Administration)

### Tasks

1. **External system sync**
   - ExternalSyncService with adapter pattern
   - On application submitted → push volunteer data to external API
   - Retry with exponential backoff (3 attempts)
   - ExternalSyncLog tracks every attempt
   - Transfer status visible on volunteer profile

2. **Inbound webhooks**
   - `Webhooks::ExternalSystemController` (no auth, HMAC signature verification)
   - Handle events: application submitted, application approved
   - Idempotency checks (no duplicate processing)
   - Audit logging

3. **Data import**
   - Admin UI for CSV/Excel upload
   - VolunteerImportService with duplicate detection
   - Preview before import (show what will be created/updated/skipped)
   - Background processing for large files
   - Import history log

4. **Admin settings**
   - SystemSetting management UI
   - Configurable: reminder frequencies, email intervals, notification recipients
   - Role-based access (admin only)

5. **User management**
   - Admin can create/edit/deactivate staff accounts
   - Role assignment
   - Activity log (optional)

### Deliverable
Volunteer data syncs to external system on application. Historical data importable from spreadsheets. Admin settings configurable through UI.

---

## Cross-Cutting Concerns

These apply across all phases:

### Testing Strategy
- **Unit tests:** Models, services, jobs (Minitest, already configured)
- **Controller tests:** Request specs for all endpoints
- **System tests:** Key user flows with Capybara + Selenium
- **Fixture data:** Build as models are implemented

### Error Handling
- Sentry or similar for production error tracking (optional)
- Graceful error pages
- Job failure notifications

### Logging
- Follow Wide Events pattern (per project conventions)
- One canonical log line per request/operation
- Structured JSON logging in production

### Security
- CSRF protection on all forms
- Rate limiting on public endpoints
- Input sanitization
- SQL injection prevention (ActiveRecord handles this)
- XSS prevention (Rails auto-escaping)

---

## Dependency Graph

```
Phase 1 (Foundation)
    │
    v
Phase 2 (Volunteer CRUD + Forms + Status)
    │
    ├──────────────┐
    v              v
Phase 3         Phase 6
(Sessions)      (Notes)
    │              │
    v              v
Phase 4         Phase 7
(Email)         (SMS)
    │
    v
Phase 5
(Applications)
    │
    ├──────────┐
    v          v
Phase 8     Phase 9
(Reports)   (Integrations)
```
