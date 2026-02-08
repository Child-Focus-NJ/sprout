# Feature Specifications

Detailed implementation specifications for each feature, derived from user stories. Each section maps directly to a user story and includes: data model notes, routes, controllers, views, services, jobs, and key implementation details.

---

## Feature 01: Public Inquiry Form Submission

**User Story:** As a potential volunteer, I want to sign up for an information session through a form, so that I can learn about volunteer opportunities.

### Routes
```ruby
# Public (no auth)
scope :public do
  resources :inquiries, only: [:new, :create], controller: "public/inquiries"
  get "thank-you", to: "public/inquiries#thank_you"
end
```

### Controller: `Public::InquiriesController`
- `new` — Render form
- `create` — Validate, save InquiryFormSubmission, enqueue ProcessInquiryJob
- `thank_you` — Confirmation page

### Form Fields
| Field | Type | Required | Notes |
|-------|------|----------|-------|
| first_name | text | Yes | |
| last_name | text | Yes | |
| email | email | Yes | Used for duplicate detection |
| phone | tel | No | |
| referral_source_id | select | Yes | From ReferralSource table |
| referral_person_name | text | Conditional | Shown when referral is "person" |
| referral_person_email | email | Conditional | Shown when referral is "person" |
| event_name | text | No | Which info session they're interested in |

### Processing Flow
1. Form submitted → InquiryFormSubmission saved with `status: :pending`
2. ProcessInquiryJob runs:
   - Check for existing Volunteer by email
   - If exists: link submission, don't create duplicate
   - If new: create Volunteer with `current_funnel_stage: :inquiry`, set `inquiry_date`
   - Mark submission as `processed`
   - Send notification email to Sarah (configurable recipient via SystemSetting)
   - Create ScheduledReminder records for follow-up intervals

### Bot Protection
- Invisible Captcha honeypot field
- Rack::Attack: 5 submissions per IP per hour, 3 per email per day
- Timestamp check: reject submissions faster than 4 seconds

---

## Feature 02: Account Management

**User Story:** As a system administrator, I want to manage volunteer accounts without duplicates, so that I can track the full volunteer journey accurately.

### Duplicate Detection Strategy

**On form submission (automatic):**
1. Exact email match → link to existing account
2. Normalized email match (lowercase, trim) → link to existing

**On admin create/edit (with UI prompt):**
1. Exact email match → warn, offer to view existing
2. Name + phone match → warn as potential duplicate
3. Similar name (Levenshtein distance) → suggest as possible match

### Account Linking

The Volunteer model has a self-referencing `linked_account_id` field for when someone uses different emails for inquiry vs. application.

**Admin UI:**
- "Link Account" button on volunteer profile
- Search modal to find the other account
- Display linked account on profile with quick navigation
- Merge option: combine communication history, keep newer contact info

### Referral Propagation

When `referral_source` is "Person":
- Store referrer name and email on the volunteer
- If referrer is also a volunteer, link via `referred_by_volunteer_id`
- Show referral chain on volunteer profile

---

## Feature 03: Email Automation

**User Story:** As a system administrator, I want to automate email communications, so that I don't need to re-enter data or manually send emails.

### Automated Email Triggers

| Trigger | Timing | Template Category | Action |
|---------|--------|-------------------|--------|
| New inquiry | Immediately | Welcome | Send welcome email |
| No session registration | 2 weeks after inquiry | Follow-up | Encourage signup |
| No session registration | 4 weeks after inquiry | Follow-up | Second reminder |
| No session registration | 8 weeks after inquiry | Follow-up | Third reminder |
| No session registration | 12 weeks after inquiry | Follow-up | Final reminder |
| Session attended | Immediately | Application | Send application email |
| Session skipped/cancelled | Next day | Re-engage | Offer to reschedule |
| Application sent, not submitted | Configurable interval | App reminder | Remind to submit |

### Scheduling Architecture

**Recurring job** (Solid Queue, `config/recurring.yml`):
```yaml
process_scheduled_reminders:
  class: ProcessScheduledRemindersJob
  schedule: "every 5 minutes"
```

**Flow:**
1. Volunteer enters funnel → `CreateIntervalRemindersJob` creates ScheduledReminder records
2. Every 5 min → `ProcessScheduledRemindersJob` finds due reminders
3. For each due reminder → enqueues `SendReminderJob`
4. `SendReminderJob` renders template with Liquid, sends via Postmark/SendGrid, records Communication

**Cancellation rules:**
- On attendance confirmed: cancel all pending follow-up reminders
- On application submitted: cancel all pending application reminders
- On marked inactive: cancel all pending reminders

### Email Tracking
- Each send creates a Communication record
- External message ID stored for delivery tracking
- Postmark webhook for bounces/opens (optional)
- `sent_at` timestamp on Communication and ScheduledReminder

---

## Feature 04: Email Templates

**User Story:** As a system administrator, I want to create and manage email templates, so that I can send consistent, timely communications.

### Routes
```ruby
namespace :admin do
  resources :communication_templates do
    member do
      get :preview
      post :duplicate
    end
  end
end
```

### Template Model (already exists)
Key fields: `name`, `subject`, `body`, `template_type` (email/sms), `funnel_stage`, `trigger_type`, `interval_weeks`, `active`

### Template Editor UI
- **Subject line:** Text field with Liquid variable insertion buttons
- **Body:** ActionText/Trix rich text editor
- **Variable palette:** Sidebar with clickable variables that insert into editor
  - `{{first_name}}`, `{{last_name}}`, `{{full_name}}`
  - `{{email}}`, `{{phone}}`
  - `{{inquiry_date}}`, `{{session_date}}`
  - `{{current_date}}`, `{{organization_name}}`
- **Preview:** Renders template with sample volunteer data
- **Settings:** Funnel stage, trigger type, interval weeks, active toggle

### Template Categories
- **Interval-based:** Linked to `interval_weeks` (2, 4, 8, 12)
- **Event-triggered:** Linked to `trigger_type` (attendance, application_sent, etc.)
- **Special occasion:** Manually sent, tagged by occasion
- **One-off:** For manual sends, not automated

---

## Feature 05: Status Management

**User Story:** As a system administrator, I want to track and update volunteer status, so that I know where each volunteer is in the process.

### Funnel Stages (already in Volunteer model)
```ruby
enum :current_funnel_stage, {
  inquiry: 0,
  application_eligible: 1,
  application_sent: 2,
  applied: 3,
  inactive: 4
}
```

### FunnelProgressionService

Encapsulates all transition logic in one place:

```ruby
class FunnelProgressionService
  def initialize(volunteer, changed_by:)
    @volunteer = volunteer
    @changed_by = changed_by
  end

  def advance_to(stage, reason: nil)
    return if @volunteer.current_funnel_stage == stage.to_s

    previous_stage = @volunteer.current_funnel_stage

    ActiveRecord::Base.transaction do
      @volunteer.update!(current_funnel_stage: stage)
      record_status_change(previous_stage, stage, reason)
      trigger_side_effects(previous_stage, stage)
    end
  end

  private

  def record_status_change(from, to, reason)
    StatusChange.create!(
      volunteer: @volunteer,
      changed_by_user: @changed_by,
      previous_stage: from,
      new_stage: to,
      reason: reason,
      changed_at: Time.current
    )
  end

  def trigger_side_effects(from, to)
    case to.to_sym
    when :application_eligible
      # Stop inquiry follow-up reminders
      cancel_pending_reminders(:follow_up)
    when :application_sent
      # Prevent duplicate sends
      return if @volunteer.application_sent_at.present?
      @volunteer.update!(application_sent_at: Time.current)
    when :applied
      @volunteer.update!(application_submitted_at: Time.current)
      cancel_pending_reminders(:application)
    when :inactive
      @volunteer.update!(
        became_inactive_at: Time.current,
        weeks_at_inactivation: weeks_in_funnel
      )
      cancel_all_pending_reminders
    end
  end
end
```

### Status Display
- Color-coded badges: inquiry (blue), eligible (green), app sent (yellow), applied (purple), inactive (gray)
- Status change log visible on profile with timestamps and who made the change
- Filter volunteer list by status

### Automatic vs. Manual Transitions
| From → To | Trigger | Type |
|-----------|---------|------|
| inquiry → application_eligible | Attends session | Automatic |
| application_eligible → application_sent | Application email sent | Automatic |
| application_sent → applied | Application submitted | Automatic or manual |
| any → inactive | Admin decision or time-based | Manual |
| inactive → inquiry | Reactivation | Manual |

---

## Feature 06: Application Process

**User Story:** As a system administrator, I want to automate the application process, so that volunteers receive and submit applications efficiently.

### Application Flow
1. Volunteer attends info session (Phase 3 trigger)
2. System automatically sends application email with link
3. Volunteer status → `application_sent`
4. If no submission: system sends reminders at configurable intervals
5. Volunteer submits application (external system or manual mark)
6. Status → `applied`
7. All application reminders cancelled

### Application Reminders
- Configurable via SystemSetting: `application_reminder_interval_weeks`
- Default: 2 weeks, then 4 weeks
- Maximum reminders configurable (default: 3)
- Each reminder recorded as Communication + Note

### Duplicate Prevention
- Check `application_sent_at` before sending
- If already sent, skip (don't send again)
- Admin can manually resend with confirmation dialog

### Application Dashboard View
Staff need a focused view of the application pipeline:
- **Awaiting submission:** Volunteers with `application_sent` status, sorted by days waiting
- **Recently submitted:** Volunteers who submitted in the last 30 days
- **Overdue:** Volunteers who received application 4+ weeks ago without submitting

---

## Feature 07: SMS Integration

**User Story:** As a system administrator, I want to send SMS reminders to volunteers, so that I can reach them through multiple channels.

### Twilio Setup
- Account SID, Auth Token, Phone Number stored in Rails credentials
- Apply for Twilio.org Impact Access (nonprofit pricing)
- Register A2P 10DLC campaign for compliance

### SMS Capabilities

**Manual send:**
- From volunteer profile: compose SMS, select template or free-text
- Character count display (160 char limit for single SMS)
- Preview before sending

**Automated send:**
- Same ScheduledReminder system as email, with `communication_type: :sms`
- Respect volunteer's `preferred_contact_method`
- If preference is "both": send email + SMS
- If preference is "sms": send SMS only

**Bulk send:**
- Select volunteers from list, compose message, send to all
- Confirmation with count before sending

### SMS Tracking
- Delivery status via Twilio status callback webhook
- Statuses: queued, sent, delivered, failed, undelivered
- Inbound reply tracking (optional, requires Twilio webhook)
- All SMS recorded as Communication records, visible in timeline

### Webhook Endpoint
```ruby
# Routes
post "webhooks/twilio/status", to: "webhooks/twilio#status_update"
post "webhooks/twilio/inbound", to: "webhooks/twilio#inbound_message"
```

---

## Feature 08: Notes & Communication Tracking

**User Story:** As a system administrator, I want to track all communications with notes, so that communication history is always up-to-date.

### Notes Interface

**Add note (inline on volunteer profile):**
- Turbo Frame form that expands inline
- Content text area
- Submit creates Note with timestamp and `Current.user`
- Note appears in timeline immediately (Turbo Stream append)

**Timeline view:**
- Unified chronological list: notes + emails + SMS + status changes
- Each entry shows: icon (type), content, timestamp, creator
- Filter by type: all, notes only, emails, SMS, status changes
- Search within timeline

### Automatic Notes
System creates notes automatically for:
- Email sent: "Sent email: [template name] to [email]"
- SMS sent: "Sent SMS to [phone]: [preview]"
- Status changed: "Status changed from [old] to [new] by [user]"
- Application sent: "Application email sent"
- Session attended: "Attended info session: [session name]"

### Bulk Note Actions
From volunteer list view:
- Select multiple volunteers via checkboxes
- "Add Note" action → modal with note content
- Applies same note to all selected volunteers
- "Send Follow-up" action → select template, adds note + sends email

### UI Safety
- Note button (green, prominent) clearly separated from Delete button (red, smaller, with confirmation)
- Destructive actions require confirmation dialog

---

## Feature 09: Sign-in & Attendance

**User Story:** As a system administrator, I want to use an electronic sign-in sheet for info sessions, so that attendance is automatically tracked and triggers follow-up actions.

Sessions are primarily held via **Zoom** (virtual) but occasionally **in-person**. Attendance tracking should be automated for Zoom sessions and manual for in-person.

### Routes
```ruby
namespace :admin do
  resources :information_sessions do
    member do
      get :signin           # Tablet sign-in interface (in-person)
      get :attendees        # Attendee list + unmatched review
      post :sync_zoom       # Trigger Zoom attendance sync
      post :upload_attendance  # Upload Zoom CSV
    end
    resources :session_registrations, only: [:create, :update, :destroy]
  end
end

namespace :webhooks do
  post "zoom", to: "zoom#create"  # Zoom webhook endpoint (optional Phase 2)
end
```

### Session Types

| Type | Attendance Method | Automation Level |
|------|-------------------|-----------------|
| **Virtual (Zoom)** | Zoom Reports API sync + CSV fallback | Automatic (with manual review for unmatched) |
| **In-person** | Tablet sign-in interface | Manual check-in |

### Zoom Automated Attendance (Virtual Sessions)

**Zoom API Setup:**
- Create Server-to-Server OAuth app on Zoom Marketplace
- Scopes: `meeting:read:admin`, `report:read:admin`
- Requires Zoom Pro or higher (50% nonprofit discount available)

**Sync flow:**
1. Admin creates InformationSession with `session_type: :virtual` and enters `zoom_meeting_id`
2. Meeting happens on Zoom
3. 20 minutes after scheduled end time → `Zoom::AttendanceSyncJob` runs automatically
4. Job authenticates via Server-to-Server OAuth, calls `GET /report/meetings/{meetingId}/participants`
5. For each participant returned by Zoom:
   - Match by email against registered volunteers (case-insensitive)
   - If matched → mark SessionRegistration as `attended`, fire attendance triggers
   - If no email from Zoom → attempt fuzzy match on display name vs volunteer first+last name
   - If still unmatched → store in `unmatched_participants` for admin review
6. Admin receives summary notification: "Synced attendance for [Session Name]: 8 matched, 2 need review"

**Matching strategy (priority order):**
1. Exact email match (normalized lowercase) — ~70-80% of participants
2. Fuzzy name match (Zoom display name vs volunteer name) — flagged for confirmation
3. Unmatched — admin manually links or dismisses

**Admin review UI (on session attendees page):**
- Section: "Needs Review" showing unmatched Zoom participants with name, email (if any), duration
- For each: "Link to Volunteer" dropdown/search, or "Dismiss" (not a registered volunteer)
- Linking fires the same attendance triggers as an automatic match

**Service: `Zoom::Client`**
```ruby
class Zoom::Client
  BASE_URL = "https://api.zoom.us/v2"

  def initialize
    @account_id = Rails.application.credentials.dig(:zoom, :account_id)
    @client_id = Rails.application.credentials.dig(:zoom, :client_id)
    @client_secret = Rails.application.credentials.dig(:zoom, :client_secret)
  end

  def participant_report(meeting_id)
    token = fetch_access_token
    response = HTTParty.get(
      "#{BASE_URL}/report/meetings/#{meeting_id}/participants",
      headers: { "Authorization" => "Bearer #{token}" },
      query: { page_size: 300 }
    )
    response.parsed_response
  end

  private

  def fetch_access_token
    response = HTTParty.post(
      "https://zoom.us/oauth/token",
      body: { grant_type: "account_credentials", account_id: @account_id },
      basic_auth: { username: @client_id, password: @client_secret }
    )
    response["access_token"]
  end
end
```

**Job: `Zoom::AttendanceSyncJob`**
```ruby
class Zoom::AttendanceSyncJob < ApplicationJob
  queue_as :default

  def perform(information_session_id)
    session = InformationSession.find(information_session_id)
    return unless session.virtual? && session.zoom_meeting_id.present?

    participants = Zoom::Client.new.participant_report(session.zoom_meeting_id)
    Zoom::AttendanceMatcherService.new(session, participants).process
  end
end
```

### Zoom CSV Upload (Fallback)

For when the API sync misses people, or as the initial implementation before API integration is built.

**Flow:**
1. Admin downloads attendance CSV from Zoom web portal (Reports → Usage)
2. On session page, clicks "Upload Attendance CSV"
3. `Zoom::CsvAttendanceProcessor` parses the CSV
4. Same matching logic as API sync (email first, then name)
5. Results shown immediately: matched, needs review, already marked

**CSV fields used:** Name, Email, Join Time, Leave Time, Duration

### Manual Sign-in (In-Person Sessions)

**Tablet-optimized interface:**
- Minimal UI: large text, big touch targets, high contrast
- Search field at top: type name or email to find registered volunteer
- List of registered volunteers with large "Check In" button
- "Walk-in" button to add someone not pre-registered (quick form: first name, last name, email)
- Real-time attendee count display
- Auto-refresh via Turbo Streams

**Walk-in handling:**
1. Staff taps "Add Walk-in"
2. Quick form: first name, last name, email (minimal fields)
3. System creates Volunteer (with duplicate check) + SessionRegistration
4. Same attendance triggers fire

### Attendance Triggers (Shared by All Methods)

Regardless of how attendance is recorded (Zoom sync, CSV upload, or manual), the same downstream effects fire:

1. SessionRegistration status → `attended`
2. Volunteer's `first_session_attended_at` set (if first time)
3. FunnelProgressionService advances to `application_eligible`
4. All pending follow-up reminders cancelled
5. Application email queued (if email system built)
6. StatusChange audit record created
7. Note created: "Attended info session: [name] on [date]"

### Database Additions

```ruby
# Add to information_sessions
add_column :information_sessions, :session_type, :integer, default: 0  # 0=virtual, 1=in_person
add_column :information_sessions, :zoom_meeting_id, :string
add_column :information_sessions, :zoom_join_url, :text
add_column :information_sessions, :last_attendance_sync_at, :datetime

# Add to session_registrations
add_column :session_registrations, :zoom_participant_id, :string
add_column :session_registrations, :zoom_join_time, :datetime
add_column :session_registrations, :zoom_leave_time, :datetime
add_column :session_registrations, :zoom_duration_minutes, :integer
add_column :session_registrations, :match_method, :string  # 'zoom_email', 'zoom_name', 'csv', 'manual'
```

---

## Feature 10: Reporting & Data Export

**User Story:** As a system administrator, I want to generate reports and export data, so that I can analyze trends and use data in other systems.

### Routes
```ruby
namespace :admin do
  resources :reports, only: [:index] do
    collection do
      get :funnel_overview
      get :year_comparison
      get :session_attendance
      get :communication_summary
    end
  end
  resources :exports, only: [:new, :create]
end
```

### Dashboard Analytics (Chartkick)
- **Funnel overview:** Bar chart of volunteers at each stage
- **Inquiries over time:** Line chart, monthly, with year-over-year
- **Session attendance:** Per session, over time
- **Conversion rates:** Inquiry → attended → applied percentages
- **Communication volume:** Emails/SMS sent per month

### PDF Reports (Grover)
- Same HTML views rendered as PDF
- `@media print` CSS for clean print layout
- Page breaks between sections
- Header with org logo, date, title
- Footer with page numbers

### Data Export
- **CSV export** from volunteer list with current filters
- **Full export** with all fields or selected fields
- **Communication export** for a date range
- **Session export** with attendee lists
- Date range picker for all exports

---

## Feature 11: External Integration & Administration

**User Story:** As a system administrator, I want to integrate with external systems and manage settings, so that data stays synchronized and the system is configurable.

### External System Sync

**Outbound (on application submitted):**
1. Volunteer submits application → SyncVolunteerJob enqueued
2. ExternalSyncService posts volunteer data to external API
3. On success: store external_id, update external_synced_at
4. On failure: retry 3x with exponential backoff, log to ExternalSyncLog
5. Transfer status visible on volunteer profile with date/time

**Inbound (webhooks):**
- Endpoint for external system to notify of events
- HMAC signature verification
- Idempotency via payload hash
- Updates volunteer status based on event type

### Data Import

**Admin import UI:**
1. Upload CSV/Excel/JSON file
2. Column mapping step (match file columns to volunteer fields)
3. Preview: show first 10 rows with what will happen (create/update/skip)
4. Confirm → ImportVolunteersJob processes in background
5. Results page: created, updated, duplicates skipped, errors

**Duplicate detection during import:**
- Primary: exact email match
- Secondary: first name + last name + phone match
- Admin decides: skip duplicates or update existing records

### Admin Settings

**SystemSetting management UI:**
- Key-value pairs with type (string, integer, boolean)
- Settings:
  - `notification_email` — Who gets notified on new inquiries
  - `follow_up_intervals` — Comma-separated weeks (2,4,8,12)
  - `application_reminder_interval` — Weeks between app reminders
  - `max_application_reminders` — Maximum reminder count
  - `organization_name` — Used in email templates
  - `external_api_url` — External system endpoint

### User Management (Admin Only)
- List staff users with roles
- Create new user (invite by email)
- Edit role (admin/staff/viewer)
- Deactivate user (soft delete)
- No self-service registration — admin creates all accounts
