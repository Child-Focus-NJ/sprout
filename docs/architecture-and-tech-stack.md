# Architecture & Tech Stack Decisions

This document captures the technical architecture and tooling decisions for Sprout, a volunteer management system for Child Focus NJ.

## System Overview

Sprout manages the full volunteer lifecycle: inquiry form submission, information session attendance, application processing, and ongoing communication. It replaces manual Google Sheets workflows with an automated system.

**Users:**
- 3-5 staff administrators (Sarah and team)
- 100-500 volunteers being tracked through the funnel
- Public visitors submitting inquiry forms

**Volunteer Funnel:**
```
Inquiry → Info Session Registered → Attended Session → Application Sent → Applied → (Inactive)
         ↑                                                                    │
         └────────────── Automated follow-up emails at 2/4/8/12 weeks ───────┘
```

---

## Current Foundation (Already Built)

| Layer | Status | Details |
|-------|--------|---------|
| **Framework** | Rails 8.1.2 | Modern Rails with Solid suite |
| **Database** | PostgreSQL 16 | 13 migrations, well-indexed schema |
| **Models** | 13 models | Volunteer, User, Communication, CommunicationTemplate, ScheduledReminder, InformationSession, SessionRegistration, Note, StatusChange, ExternalSyncLog, InquiryFormSubmission, ReferralSource, SystemSetting |
| **Background Jobs** | Solid Queue | Configured but no jobs defined |
| **Caching** | Solid Cache | Configured |
| **WebSockets** | Solid Cable | Configured |
| **Dev Environment** | Docker Compose | PostgreSQL + Rails, live code reloading |
| **Deployment** | Kamal | Gem present, not configured |
| **Auth Gem** | OmniAuth 2.0 | In Gemfile, unconfigured |
| **Controllers** | Minimal | Only WelcomeController with empty index |
| **Views** | Minimal | Welcome page with logo only |

---

## Tech Stack Decisions

### 1. Authentication

**Decision: Rails 8 built-in authentication generator + Google OAuth**

Rails 8 ships a `bin/rails generate authentication` command that produces ~200 lines of transparent, modifiable code. For 3-5 staff users on a nonprofit tool, this is the right level of complexity.

**Why not Devise?** Overkill. Devise brings 10+ modules (confirmable, lockable, omniauthable, etc.) that a 3-5 user admin tool doesn't need. The Rails 8 generator is maintained by the core team and gives full code ownership.

**Google OAuth as primary login:** The nonprofit likely uses Google Workspace. Staff sign in with their existing Google accounts — no passwords to manage.

**Gems required:**
```ruby
gem "bcrypt", "~> 3.1.7"              # Required by Rails 8 auth generator
gem "omniauth-google-oauth2"           # Google OAuth provider
gem "omniauth-rails_csrf_protection"   # CSRF protection for OAuth
```

**Setup steps:**
1. Run `bin/rails generate authentication` (creates Session model, SessionsController, Current class)
2. Configure Google Cloud Console OAuth credentials
3. Store credentials via `bin/rails credentials:edit`
4. Add OmniAuth initializer with `hd:` domain restriction
5. Add Google callback route and handler

### 2. Authorization

**Decision: Simple `before_action` checks (no gem)**

With only 3 roles (admin, staff, viewer), authorization gems like Pundit or CanCanCan add unnecessary abstraction. Simple helper methods in `ApplicationController` are sufficient:

```ruby
def require_admin
  redirect_to root_path unless Current.user&.admin?
end

def require_staff_or_admin
  redirect_to root_path unless Current.user&.admin? || Current.user&.staff?
end
```

**Upgrade path:** If roles exceed 5 or per-object permissions are needed, migrate to Pundit.

### 3. CSS Framework

**Decision: Tailwind CSS via `tailwindcss-rails`**

The `tailwindcss-rails` gem is maintained by the Rails core team. It uses a standalone executable — no Node.js, no webpack, no esbuild. Works perfectly with Importmap and Propshaft.

```ruby
gem "tailwindcss-rails"
```

**Why not Bootstrap?** Bootstrap works well but Tailwind integrates more cleanly with Rails 8 defaults and produces smaller CSS bundles. The utility-first approach is faster for building custom admin interfaces.

### 4. Email Service

**Decision: MailChimp — team already has it**

The team already uses MailChimp, so we'll lean on it for both transactional email delivery and audience/campaign management. Two integration points:

#### 4a. Transactional Email (Mandrill) — sending event-driven emails

For emails triggered by app events (inquiry confirmation, application sent, session reminders), use MailChimp Transactional (Mandrill) via SMTP relay with ActionMailer.

| Detail | Value |
|--------|-------|
| **Service** | MailChimp Transactional (Mandrill) |
| **Free tier** | 500 emails/month to verified domains |
| **Paid blocks** | $20 per 25,000 emails (if needed) |
| **Requirement** | MailChimp Standard or Premium plan |

```ruby
# config/environments/production.rb
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address: "smtp.mandrillapp.com",
  port: 587,
  user_name: Rails.application.credentials.dig(:mailchimp, :username),
  password: Rails.application.credentials.dig(:mailchimp, :transactional_api_key),
  authentication: :plain,
  enable_starttls_auto: true
}
```

No extra gem needed for sending. Delivery tracking (bounces, opens, clicks) via Mandrill webhooks.

#### 4b. MailChimp Marketing API — audience sync, campaigns, and reporting

The official [`mailchimp-marketing-ruby`](https://github.com/mailchimp/mailchimp-marketing-ruby) gem gives programmatic access to MailChimp's full platform. This is valuable for:

- **Audience sync:** Keep the MailChimp subscriber list in sync with the volunteer database. When a volunteer is created or changes status, update their MailChimp profile and tags automatically.
- **Segmentation:** Tag volunteers by funnel stage (`inquiry`, `attended`, `applied`, etc.) so MailChimp segments stay current for any campaigns the team sends directly from MailChimp.
- **Campaign reports:** Pull open/click rates and campaign analytics into the Sprout reporting dashboard.
- **Template management:** Optionally manage email templates in MailChimp's editor (which the team may already be familiar with) and pull them into the app.

```ruby
gem "MailchimpMarketing", git: "https://github.com/mailchimp/mailchimp-marketing-ruby.git"
```

```ruby
# config/initializers/mailchimp.rb
require "MailchimpMarketing"

MAILCHIMP = MailchimpMarketing::Client.new({
  api_key: Rails.application.credentials.dig(:mailchimp, :api_key),
  server: Rails.application.credentials.dig(:mailchimp, :server_prefix)  # e.g., "us19"
})
```

**How the two pieces work together:**
| Need | Tool |
|------|------|
| Send a single transactional email (confirmation, reminder) | ActionMailer via Mandrill SMTP |
| Sync a volunteer to the MailChimp audience | Marketing API (`lists.add_list_member`) |
| Tag a volunteer by funnel stage | Marketing API (`lists.update_list_member_tags`) |
| Pull campaign open/click reports | Marketing API (`reports.get_campaign_report`) |
| Send a seasonal bulk campaign | MailChimp web UI (team already knows how) |

### 5. SMS Service

**Decision: Twilio**

Twilio is the standard for programmatic SMS. Their nonprofit Impact Access Program provides $100 in free credits and reduced rates.

**Note:** The user story mentions "MailChimp/SendGrid" for SMS. MailChimp does offer SMS as a marketing add-on, but it's designed for bulk marketing campaigns — not programmatic transactional messages triggered by app events. Twilio is the right tool for automated, event-driven SMS (session reminders, application follow-ups, etc.).

```ruby
gem "twilio-ruby"
```

**Estimated cost:** $0-7/month ($3 campaign fee + ~$0.008/SMS).

### 6. Email Template Rendering

**Decision: Liquid templating with database-stored templates**

The `CommunicationTemplate` model already exists with `body`, `subject`, `funnel_stage`, and `interval_weeks` fields. Use Liquid for safe variable interpolation that non-technical admins can edit:

```
Hi {{first_name}}, thank you for your interest in volunteering...
```

```ruby
gem "liquid"
```

**Why Liquid?** Safe (no code execution), battle-tested (Shopify), simple for admins. Templates stored in the database can be edited at runtime without deployments.

### 7. Rich Text Editor

**Decision: ActionText with Trix (built-in)**

ActionText ships with Rails. Trix provides basic formatting (bold, italic, lists, links) — sufficient for email templates. Start here and upgrade to Rhino Editor (TipTap-based) only if Trix limitations become painful.

No additional gems needed — just run `rails action_text:install`.

### 8. Pagination & Filtering

**Decision: Pagy + Ransack**

```ruby
gem "pagy"      # Fastest pagination gem, Hotwire-ready
gem "ransack"   # Filtering/searching with Turbo support
```

Pagy is 40x faster than Kaminari/WillPaginate. Ransack provides object-based searching that integrates well with Turbo Frames for no-refresh filtering.

### 9. Charts & Reporting

**Decision: Chartkick + Chart.js + Grover**

```ruby
gem "chartkick"  # One-line Ruby charts
gem "grover"     # HTML-to-PDF via headless Chrome
```

Chartkick works with Importmap — no bundler needed. One-line charts:
```erb
<%= line_chart Volunteer.group_by_month(:inquiry_date).count %>
```

Grover renders existing HTML views as PDFs using headless Chrome, so report views work for both web and PDF without duplication.

### 10. External API Integration

**Decision: HTTParty + Retriable + Service Objects**

```ruby
gem "httparty"     # HTTP client
gem "retriable"    # Retry with exponential backoff
```

Service object pattern with adapter support for multiple external systems. Jobs handle async sync with retry logic via Solid Queue.

### 11. Data Import

**Decision: Roo + activerecord-import**

```ruby
gem "roo"                   # Read CSV/Excel/ODS
gem "activerecord-import"   # Bulk insert
```

Roo provides a unified interface for all spreadsheet formats. Large imports process via background jobs.

### 12. Zoom Integration (Attendance Tracking)

**Decision: Zoom Reports API via Server-to-Server OAuth + CSV upload as fallback**

Info sessions are held via Zoom (and occasionally in-person). Zoom's Reports API can pull participant data (email, join/leave time, duration) after a meeting ends, enabling automated attendance tracking.

**How it works:**
1. Admin creates an InformationSession in Sprout and links a Zoom meeting ID
2. After the Zoom meeting ends, a background job (20 min delay) calls the Reports API
3. The job matches participant emails against registered volunteers
4. Matched volunteers are automatically marked as attended, triggering all downstream automations (status update, application email, etc.)
5. Unmatched participants are flagged for manual review by staff

**Key constraints:**
- Reports API data is available **15 minutes** after a meeting ends
- Email matching is ~70-80% reliable (depends on participants being signed into Zoom)
- Requires Zoom **Pro plan or higher** (50% nonprofit discount available — ~$75/year)
- Requires a Server-to-Server OAuth app on the Zoom Marketplace

**CSV upload fallback:** For in-person sessions or when API matching misses people, staff can download Zoom's attendance CSV and upload it to Sprout. This is also the simplest path to implement first.

**Integration approach:** Use HTTParty (already in the stack) for direct REST API calls to Zoom. No dedicated Zoom gem — the existing Ruby gems are thin wrappers and mostly outdated.

```ruby
# config/initializers/zoom.rb (credentials stored via rails credentials:edit)
# zoom:
#   account_id: xxx
#   client_id: xxx
#   client_secret: xxx
```

**Zoom OAuth scopes needed:** `meeting:read:admin`, `report:read:admin`

**In-person sessions:** Use the tablet-friendly manual sign-in interface (no Zoom involvement). The same attendance triggers fire regardless of whether check-in was via Zoom sync or manual sign-in.

### 13. Public Form Protection

**Decision: Rack::Attack + Invisible Captcha**

```ruby
gem "rack-attack"         # Rate limiting
gem "invisible_captcha"   # Honeypot (no user interaction needed)
```

Invisible Captcha uses honeypot fields and timestamp checks — invisible to real users, catches most bots. Rack::Attack limits submissions per IP/email. No need for Google reCAPTCHA at this scale.

---

## Complete Gemfile Additions

```ruby
# Authentication
gem "bcrypt", "~> 3.1.7"
gem "omniauth-google-oauth2"
gem "omniauth-rails_csrf_protection"

# Frontend
gem "tailwindcss-rails"
gem "pagy"
gem "ransack"
gem "chartkick"

# Communications
gem "MailchimpMarketing", git: "https://github.com/mailchimp/mailchimp-marketing-ruby.git"  # Audience sync, campaigns, reports
# MailChimp Transactional (Mandrill) uses SMTP relay — no gem needed for sending
gem "twilio-ruby"
gem "liquid"

# PDF Reports
gem "grover"

# External Integrations
gem "httparty"
gem "retriable"
gem "roo"
gem "activerecord-import"

# Security
gem "rack-attack"
gem "invisible_captcha"
```

---

## Architecture Layers

```
┌────────────────────────────────────────────────────┐
│                    Public Web                        │
│  Inquiry Form (no auth, rate-limited, honeypot)     │
└─────────────────────┬──────────────────────────────┘
                      │
┌─────────────────────v──────────────────────────────┐
│                   Admin Dashboard                    │
│  Google OAuth / Email+Password login                 │
│  Role-based access (admin / staff / viewer)          │
│                                                      │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐            │
│  │Volunteers│ │ Sessions │ │Templates │  ...        │
│  │  CRUD    │ │  + Signin│ │  + Editor│             │
│  └──────────┘ └──────────┘ └──────────┘            │
└─────────────────────┬──────────────────────────────┘
                      │
┌─────────────────────v──────────────────────────────┐
│                  Service Layer                       │
│  ExternalSyncService, VolunteerImportService,       │
│  CommunicationService, FunnelProgressionService     │
└─────────────────────┬──────────────────────────────┘
                      │
┌─────────────────────v──────────────────────────────┐
│               Background Jobs (Solid Queue)          │
│  ProcessInquiryJob, SendReminderJob,                │
│  ProcessScheduledRemindersJob, SyncVolunteerJob,    │
│  ImportVolunteersJob                                 │
└─────────────────────┬──────────────────────────────┘
                      │
┌─────────────────────v──────────────────────────────┐
│              External Services                       │
│  MailChimp Transactional (email), Twilio (SMS),     │
│  Zoom (attendance sync), Google OAuth (auth),        │
│  External volunteer system (API sync)                │
└────────────────────────────────────────────────────┘
```

---

## Estimated Monthly Costs

| Service | Cost | Notes |
|---------|------|-------|
| MailChimp Transactional | $0/mo | 500 free emails/mo; already have MailChimp |
| Twilio | $0-7/mo | $100 nonprofit credit to start |
| Zoom Pro | ~$6/mo | 50% nonprofit discount (~$75/year) |
| Hosting | $5-20/mo | Kamal to a VPS, or Railway/Render |
| Domain | ~$1/mo | If not already owned |
| **Total** | **$12-49/mo** | |
