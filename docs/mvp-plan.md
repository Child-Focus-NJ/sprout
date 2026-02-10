# MVP Plan

**Goal:** A working demo that shows the core volunteer management workflow end-to-end, replacing the Google Sheets process.

---

## What the Demo Should Show

Walk through the volunteer lifecycle in a live app:

1. **A potential volunteer fills out an inquiry form** on a public page
2. **Staff logs in** and sees the new volunteer appear in a list
3. **Staff views the volunteer profile** — contact info, status, timeline
4. **Staff registers the volunteer** for an upcoming info session
5. **At the session, staff checks in the volunteer** via a sign-in interface
6. **The system automatically updates** the volunteer's status and logs the change
7. **Staff adds a note** to the volunteer's profile
8. **Staff filters and searches** the volunteer list by status, date, name

That's the story: inquiry → registration → attendance → status progression → tracking. All in one system instead of scattered spreadsheets.

---

## What's IN the MVP

### 1. Authentication & Layout
- Email/password login (Rails 8 auth generator)
- Admin layout with Tailwind CSS — sidebar nav, header, flash messages
- Seed data: one admin user, referral sources, sample volunteers
- Google OAuth deferred to post-MVP (email/password is sufficient for demo)

### 2. Volunteer Management (the core value)
- **Volunteer list** with Pagy pagination and Ransack filtering
  - Filter by: funnel stage, referral source
  - Search by: name, email
  - Sort by: name, date, status
  - Color-coded status badges
- **Volunteer detail page**
  - Profile card: name, email, phone, referral source, funnel stage, key dates
  - Status change timeline (from StatusChange records)
  - Notes section with inline add form
  - Quick-action: manual status change
- **Volunteer create/edit forms**
  - All fields with validation
  - Referral source dropdown
  - Duplicate detection warning on email

### 3. Public Inquiry Form
- Public page (no auth) at `/inquiries/new`
- Fields: first name, last name, email, phone, referral source
- On submit: creates Volunteer record with `inquiry` status
- Duplicate detection by email
- Thank-you confirmation page
- Basic bot protection (Invisible Captcha)

### 4. Information Sessions & Attendance
- **Session list and create/edit** — name, date/time, location, session type
- **Register volunteers** for a session
- **Manual sign-in interface** — simple check-in page
  - Search by name, tap to check in
  - Walk-in quick-add
- **On check-in:**
  - Status → `application_eligible`
  - `first_session_attended_at` recorded
  - StatusChange audit log entry created
  - Note auto-created

### 5. Notes
- Add notes to volunteer profiles (inline Turbo Frame form)
- Auto-generated notes on status changes and attendance
- Chronological display on volunteer detail page

### 6. Status Management
- FunnelProgressionService handles transitions
- StatusChange records created on every transition
- Manual status override from volunteer detail page
- Visual timeline of status history

### 7. Seed Data for Demo
- 1 admin user (demo login)
- 5-6 referral sources (Website, Friend, Social Media, Community Event, etc.)
- 30-50 sample volunteers spread across all funnel stages
- 3-4 information sessions (past and upcoming)
- Sample notes and status changes to show realistic timelines

---

## What's OUT of the MVP

These are all planned features (documented in the roadmap) but not needed for the MVP:

| Feature | Why Deferred |
|---------|-------------|
| Google OAuth | Email/password works for demo. Add after. |
| Email automation | Needs Mandrill setup, template system, scheduling jobs. Large effort. |
| Email template editor | Depends on email automation. |
| Zoom API attendance sync | Needs Zoom app approval + Pro account. Manual sign-in covers the demo. |
| Zoom CSV upload | Nice to have but manual sign-in demonstrates the concept. |
| SMS integration | Uses Mandrill Transactional SMS. Not core to the demo story. |
| PDF reports / charts | Valuable but not needed to show the core workflow. |
| Data import (CSV/Excel) | Post-launch feature for historical data migration. |
| External system sync | Needs external API details. Post-MVP. |
| Admin settings UI | Can hardcode settings for demo. |
| User management UI | Seed the admin user. Manage users later. |
| Role-based authorization | All demo users are admin. Add roles after. |
| Bulk actions | Single-volunteer actions are sufficient for demo. |
| MailChimp audience sync | Needs MailChimp API setup. Post-MVP. |

---

## Build Sequence

Work is ordered so that each step builds on the previous and the app is demoable at any point after Step 4.

### Steps 1-2: Foundation

**Step 1: Auth + Layout**
- Install Tailwind CSS (`tailwindcss-rails`)
- Run `bin/rails generate authentication`
- Create admin layout: sidebar nav, header, content area, flash messages
- Build login page
- Seed admin user

**Step 2: Shared UI + Pagy/Ransack**
- Install Pagy and Ransack, create initializers
- Build shared partials: `_flash`, `_pagination`, status badge helper
- Set up Turbo Frame patterns for inline forms
- Seed referral sources and system settings

*Checkpoint: Staff can log in and see an empty dashboard.*

### Steps 3-5: Volunteer CRUD

**Step 3: Volunteer list**
- `VolunteersController#index`
- List view with table: name, email, phone, status, inquiry date
- Ransack search (name, email) and funnel stage filter
- Pagy pagination
- Color-coded status badges

**Step 4: Volunteer detail + create**
- `VolunteersController#show` — profile card, key dates, status badge
- `VolunteersController#new/create` — form with validation, referral source dropdown
- Duplicate detection on email (flash warning)

**Step 5: Volunteer edit + status + timeline**
- `VolunteersController#edit/update`
- FunnelProgressionService for status transitions
- Status change UI (dropdown or buttons on detail page)
- StatusChange timeline display on detail page
- Seed 30-50 sample volunteers across funnel stages

*Checkpoint: Staff can view, create, edit, search, filter volunteers. Status changes tracked.*

### Steps 6-7: Public Inquiry Form

**Step 6: Form + processing**
- `Public::InquiriesController` (no auth)
- Form page with fields, Invisible Captcha
- On submit: find-or-create Volunteer with `inquiry` status
- Thank-you page
- Basic Rack::Attack rate limiting

**Step 7: Notification + polish**
- Send email notification to admin on new inquiry (ActionMailer with letter_opener in dev)
- Link InquiryFormSubmission to Volunteer
- Show inquiry submissions on volunteer detail page
- Polish form styling for public visitors (distinct from admin UI)

*Checkpoint: End-to-end inquiry flow works. Public form → volunteer appears in admin list.*

### Steps 8-9: Sessions & Attendance

**Step 8: Session CRUD + registration**
- `InformationSessionsController` — list, create, edit
- Session detail page with registered volunteers list
- Register/unregister volunteers from session page
- Register from volunteer profile page

**Step 9: Sign-in + attendance triggers**
- Sign-in interface (simplified, works on tablet)
- Search by name, "Check In" button
- Walk-in quick-add form
- On check-in: FunnelProgressionService advances status
- Auto-note created, StatusChange logged
- `first_session_attended_at` recorded

*Checkpoint: Full workflow demoable: inquiry → register → attend → status updates automatically.*

### Steps 10-11: Notes + Polish

**Step 10: Notes system**
- Inline note form on volunteer detail (Turbo Frame)
- Auto-notes on status changes and attendance (if not already done)
- Chronological display
- Note type indicators (manual vs system-generated)

**Step 11: Demo polish**
- Realistic seed data with varied dates, statuses, notes
- Dashboard landing page with key counts (total inquiries, active volunteers, upcoming sessions)
- Navigation polish — active states, breadcrumbs
- Empty states (no volunteers yet, no sessions yet)
- Flash message polish
- Mobile/tablet responsiveness check for sign-in page

*Checkpoint: App is polished and demo-ready.*

### Step 12: Demo Prep

- Final seed data review — does the demo story flow?
- Practice the demo walkthrough
- Deploy to a staging URL (Railway, Render, or Kamal to a VPS) so it's accessible
- Write demo script/talking points
- Test on the actual device/browser that will be used for the presentation

---

## Demo Script Outline

> "This is Sprout — a volunteer management system that replaces our spreadsheet-based process."

1. **Public inquiry form** — "When someone visits our website and wants to learn about volunteering, they fill out this form." → Submit form
2. **Admin login** — "Sarah logs in and sees the new inquiry at the top of her list."
3. **Volunteer list** — "She can filter by status, search by name, and see everyone in the pipeline at a glance."
4. **Volunteer profile** — "She clicks in and sees the full picture — when they inquired, their referral source, their status."
5. **Register for session** — "She registers this volunteer for next week's info session."
6. **Session sign-in** — "At the session, we open the sign-in page on a tablet. Volunteers check in by name."
7. **Auto-status update** — "After check-in, the volunteer's status automatically changed to 'eligible for application' — no manual update needed."
8. **Notes** — "Sarah adds a note about the conversation they had."
9. **Timeline** — "Every action is tracked — when they inquired, when they attended, every status change, every note."
10. **What's next** — "Coming soon: automated email follow-ups, Zoom attendance sync, SMS reminders, and reporting."

---

## Technical Requirements for Demo Day

- [ ] Deployed to an accessible URL (not just localhost)
- [ ] SSL certificate (free via Let's Encrypt or platform default)
- [ ] Seeded with realistic demo data
- [ ] Admin login credentials documented
- [ ] Tested in the browser/device that will be used for the presentation
- [ ] Backup plan if internet is spotty (local Docker setup as fallback)
