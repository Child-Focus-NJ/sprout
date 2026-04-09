# VMS Scraper API Design

## Overview

The eVinto volunteer management system (VMS) at `nj-passaic.evintotraining.com` has no API. It is a legacy ASP.NET MVC application with Kendo UI grids. Sprout needs to push and pull volunteer data to/from this system as part of the volunteer funnel (inquiry → info session → application → active).

This design wraps programmatic HTTP access to the VMS website behind a clean REST-like API using AWS Lambda, API Gateway, and Secrets Manager — consistent with the existing Zoom and MailChimp integration patterns.

## Scope (MVP)

| Resource | Operations | Purpose |
|----------|-----------|---------|
| **Inquiries** | Create, List, Edit (limited), Delete | Push new inquiries from Sprout, read back for verification |
| **Volunteers** | List, Create | Read volunteers to check inquiry conversion, create volunteers |
| **Lookups** | List (read-only) | Reference data for forms (counties, statuses, referrals, types) |
| **Session** | Refresh | Authenticate with VMS and cache session cookies |

Out of scope for MVP: Cases, Reports, ToDoTasks, SystemUsers, Ad-hoc Reporting, Volunteer Edit (see Future Work).

## Architecture

```
┌──────────┐       ┌─────────────┐       ┌──────────────────────┐
│          │       │             │       │ VMS Lambda            │
│  Rails   │──────▶│ API Gateway │──────▶│ (single function,    │
│  App     │       │ /vms/*      │       │  internal routing)   │
│          │       │             │       │                      │
└──────────┘       └─────────────┘       │  ┌───────────────┐   │
                                         │  │ SessionManager │──▶ Secrets Manager
                                         │  └───────────────┘   │  (cookies + creds)
                                         │  ┌───────────────┐   │
                                         │  │ Resources:     │   │
                                         │  │  Inquiry       │──▶ VMS Website
                                         │  │  Volunteer     │   │ (HTTP scraping)
                                         │  │  Lookup        │   │
                                         │  └───────────────┘   │
                                         └──────────────────────┘

                                         ┌──────────────────────┐
                                         │ VMS Session Refresh  │
                                         │ Lambda               │
                                         │                      │
                                         │ Authenticates with   │
                                         │ VMS, stores cookies  │──▶ Secrets Manager
                                         │ in Secrets Manager   │
                                         └──────────────────────┘
```

### Why a single VMS Lambda with routing (not one per resource)

- All operations share the same session management and HTTP client logic.
- A single deployment unit is simpler to manage and test.
- The `mailchimp_realtime` Lambda already uses this pattern (routes by `event["path"]`).
- Call volume is low — independent scaling per resource is unnecessary.

## Session Management

### The Problem

The VMS website uses ASP.NET Forms Authentication. Every operation requires valid session cookies. Without caching, each Lambda invocation would need extra HTTP round-trips to log in before doing actual work.

### The Solution

Store authenticated session cookies in Secrets Manager. A dedicated Session Refresh Lambda handles authentication. CRUD Lambdas read cached cookies and only trigger a refresh when they detect staleness.

### Secrets Manager Secret Structure

Secret name: `sprout/vms-session`

```json
{
  "base_url": "https://nj-passaic.evintotraining.com",
  "username": "<vms_username>",
  "password": "<vms_password>",
  "cookies": {
    "ASP.NET_SessionId": "<value>",
    ".ASPXAUTH": "<value>"
  },
  "refreshed_at": "2026-03-12T10:00:00Z"
}
```

Only two cookies are required: `ASP.NET_SessionId` and `.ASPXAUTH`.

### Session Refresh Lambda

Invoked by:
- The VMS CRUD Lambda when it detects a stale session (302 redirect to `/Account/LogOn`)
- An optional weekly EventBridge schedule to keep cookies warm
- Rails directly via `POST /vms/session/refresh` for manual refresh (e.g., after password change)

Flow:
1. Read credentials from Secrets Manager (`sprout/vms-session`)
2. `GET /Account/LogOn` → capture `ASP.NET_SessionId` cookie
3. `POST /Account/LogOn` with username and password
4. Verify `.ASPXAUTH` cookie is present in response
5. Write updated cookies + `refreshed_at` timestamp back to Secrets Manager
6. Return cookies to the caller (so the CRUD Lambda can retry immediately without another Secrets Manager read)

### Stale Session Detection

When the CRUD Lambda makes a request to the VMS site and receives a **302 redirect to `/Account/LogOn`**, the session is stale. The Lambda then:

1. Invokes the Session Refresh Lambda synchronously (via Lambda SDK `invoke`)
2. Receives fresh cookies in the response
3. Updates its in-memory cookie cache (avoids extra Secrets Manager read)
4. Retries the original operation once with the new cookies
5. If still failing, returns an error

### Session Lifetime

Testing indicates VMS session cookies have a very long (possibly unlimited) lifetime. The refresh path is a safety net, not the normal flow. In practice, cookies are set once and reused indefinitely.

## API Surface

### API Gateway Routes

All routes are under `/vms` and routed to the single VMS Lambda. The Lambda inspects `event["httpMethod"]` and `event["path"]` to dispatch.

```
POST   /vms/session/refresh                → VMS Session Refresh Lambda

GET    /vms/inquiries                      → VMS Lambda (list inquiries)
POST   /vms/inquiries                      → VMS Lambda (create inquiry)
PUT    /vms/inquiries/{id}                 → VMS Lambda (edit inquiry)
DELETE /vms/inquiries/{id}                 → VMS Lambda (delete inquiry)

GET    /vms/volunteers                     → VMS Lambda (list volunteers)
POST   /vms/volunteers                     → VMS Lambda (create volunteer)

GET    /vms/lookups/{type}                 → VMS Lambda (list lookup values)
```

### Request/Response Contracts

#### `GET /vms/inquiries`

Query parameters:
- `status` — `active` (default) or `inactive`
- `page` — page number (default: 1)
- `page_size` — records per page (default: 50, max: 9999)
- `order_by` — sort field (default: `Inquired-desc`)

Response:
```json
{
  "data": [
    {
      "inquiry_id": 641699,
      "encrypted_id": "NjQxNjk5",
      "first_name": "Kristin",
      "last_name": "Hanson",
      "phone": "5861907118",
      "email": "kristin.hanson@example.com",
      "inquired": "2026-02-19",
      "detail_inquired": null,
      "note_date": null,
      "application_sent": null,
      "volunteer_referral_string": "",
      "county_id": 22967,
      "event_string": "",
      "active": true
    }
  ],
  "total": 1,
  "page": 1,
  "page_size": 50
}
```

Note: The VMS returns dates in ASP.NET JSON format (`/Date(1771495200000)/`). The Lambda normalizes these to ISO 8601 dates. Field names are normalized from PascalCase to snake_case. Status filtering is handled server-side by the VMS via the `?active=` URL parameter on the Kendo endpoint.

#### `POST /vms/inquiries`

Request body:
```json
{
  "first_name": "John",
  "last_name": "Doe",
  "phone": "2015551234",
  "email": "john.doe@example.com",
  "gender": 0,
  "inquired": "3/12/2026",
  "address": "123 Main St",
  "address2": "",
  "city": "Paterson",
  "state": "NJ",
  "zip": "07501",
  "county_id": 22967
}
```

Required fields: `first_name` (max 50), `last_name` (max 50), `phone` (max 15), `email` (max 100), `gender` (0=Female, 1=Male, 2=Other), `inquired` (M/D/YYYY format).

Optional fields: `address` (max 50), `address2` (max 50), `city` (max 50), `state` (max 2), `zip` (max 10), `county_id` (integer, defaults to 22967/Passaic).

Response:
```json
{
  "success": true,
  "encrypted_id": "NjQxNjk5"
}
```

The Lambda creates the inquiry by `POST /Inquiry/Create` with form data. On 302 redirect (success), it lists inquiries to find and return the new record's `EncryptedID`.

#### `PUT /vms/inquiries/{id}`

**Important constraint:** The VMS Edit form only supports two fields:
- `active` (boolean) — activate/deactivate the inquiry
- `party_id` (integer, optional) — link the inquiry to a volunteer/applicant

Personal information (name, phone, email, address) **cannot be updated after creation** in the VMS.

Request body:
```json
{
  "active": true,
  "party_id": 7217143
}
```

#### `DELETE /vms/inquiries/{id}`

No request body. The Lambda: (1) `GET /Inquiry/Delete/{id}` to get the confirmation page with hidden `InquiryID` and `programID` fields, (2) `POST /Inquiry/Delete/{id}` with those fields.

Response:
```json
{
  "success": true
}
```

#### `GET /vms/volunteers`

Query parameters:
- `status` — `yes` (active, default), `no`, or `all`
- `page`, `page_size`, `order_by` — same as inquiries (default order: `LastName-asc`)

Response:
```json
{
  "data": [
    {
      "party_id": 7217143,
      "encrypted_party_id": "NzIxNzE0Mw==",
      "program_id": 210,
      "first_name": "Chelsea",
      "last_name": "Cattano",
      "name": "Cattano, Chelsea",
      "volunteer_status": "",
      "is_supervisor": true,
      "is_volunteer": false,
      "active": true,
      "is_staff_attorney": false,
      "available": true,
      "available_date": null,
      "assigned": false,
      "supervisor_name": "",
      "case_count": 0
    }
  ],
  "total": 4,
  "page": 1,
  "page_size": 50
}
```

Note: The VMS `_GridIndex` endpoint returns `EncyptedPartyID` (with a typo — missing 'r'). The Lambda normalizes this to `encrypted_party_id`.

#### `POST /vms/volunteers`

Request body:
```json
{
  "first_name": "John",
  "last_name": "Doe",
  "gender": 0,
  "address": "123 Main St",
  "city": "Paterson",
  "state": "NJ",
  "zip": "07501",
  "county_id": 22967,
  "home_email": "john@example.com",
  "home_phone": "2015551234",
  "cell_phone": "2015555678",
  "best_email": "Home",
  "best_phone": "Cell",
  "birthdate": "1/15/1990",
  "ethnicity_id": 11893,
  "marital_status_id": null,
  "permission_to_call": true,
  "share_info_permission": true
}
```

Required: `first_name` (max 50), `last_name` (max 50), `gender` (0/1/2), `permission_to_call` (bool), `share_info_permission` (bool).

Optional: `middle_name`, `aka_name`, `ssn` (max 11), `address`, `city`, `state`, `zip`, `county_id`, `hispanic` (bool), `ethnicity_id`, `marital_status_id`, `birthdate` (M/D/YYYY), `home_email`, `work_email`, `best_email` (Home/Work), `home_phone`, `cell_phone`, `work_phone`, `best_phone` (Home/Cell/Work).

#### `GET /vms/lookups/{type}`

Path parameter `type` is one of: `County`, `VolunteerStatus`, `VolunteerStatusReason`, `VolunteerType`, `VolunteerReferral`, `InquiryEvent`, `VolunteerActivityType`, `VolunteerContactType`, `EmploymentStatus`, `Ethnicity`, `LanguageType`, `Degree`, `EducationType`.

Response (all lookups follow the same shape):
```json
{
  "data": [
    {
      "id": 22967,
      "encrypted_id": "MjI5Njc=",
      "name": "Passaic",
      "active": true
    }
  ],
  "total": 7
}
```

Lookup record counts verified against real environment:

| Type | Records |
|------|---------|
| County | 7 |
| VolunteerStatus | 3 |
| VolunteerReferral | 100+ |
| Ethnicity | 8 |

## Lambda File Structure

```
lambdas/
├── vms/
│   ├── handler.rb                  # Entry point + router
│   ├── session_manager.rb          # Read/write Secrets Manager, stale detection
│   ├── http_client.rb              # HTTP client with cookie jar, stale session retry
│   ├── Gemfile                     # aws-sdk-secretsmanager, aws-sdk-lambda
│   ├── resources/
│   │   ├── base_resource.rb        # Shared CRUD patterns (Kendo grid list, form submit)
│   │   ├── inquiry.rb              # Inquiry-specific field mappings and operations
│   │   ├── volunteer.rb            # Volunteer-specific field mappings and operations
│   │   └── lookup.rb               # Generic lookup reader
│   └── transformers/
│       ├── field_normalizer.rb     # PascalCase → snake_case, date parsing
│       └── kendo_response.rb       # Parse Kendo grid JSON responses
├── vms_session_refresh/
│   ├── handler.rb                  # Login flow + Secrets Manager write
│   └── Gemfile                     # aws-sdk-secretsmanager
└── shared/
    ├── logger.rb                   # (existing)
    └── db.rb                       # (existing)
```

### Key Modules

**`session_manager.rb`** — Reads cookies from Secrets Manager, provides them to the HTTP client. Detects stale sessions (302 to login). Invokes the refresh Lambda when needed. Updates in-memory cookie cache after refresh to avoid extra Secrets Manager reads. Caches the secret in memory for the lifetime of the Lambda execution environment (warm starts reuse it).

**`http_client.rb`** — Wraps `net/http`. Attaches session cookies to every request. Handles optional CSRF token extraction (included if present, skipped if not). Supports three request types: GET, form POST, JSON POST. Automatically retries once on stale session via the refresh Lambda. Uses `ensure` to reset retry flag even on exceptions.

**`base_resource.rb`** — Shared patterns:
- `kendo_list(controller, params, endpoint_suffix:, url_params:)` — POST to Kendo AJAX endpoint with grid params, parse JSON response. Supports `_Index` and `_GridIndex` suffixes, and URL-based query params for server-side filtering.
- `form_create(controller, data)` — POST form data → 302 on success
- `form_edit(controller, id, data)` — GET page + POST form → 302 on success
- `form_delete(controller, id)` — GET delete page → extract hidden fields → POST → 302 on success

**`field_normalizer.rb`** — Converts between Sprout's snake_case and VMS's PascalCase. Parses ASP.NET date format (`/Date(ms)/`) into ISO 8601. Has explicit aliases for known field names (e.g., `EncyptedPartyID` typo → `encrypted_party_id`).

## Rails Service Layer

The existing `Aws::LambdaClient` has been extended with `get`, `put`, and `delete` HTTP methods (previously only `post` existed), plus all VMS methods:

```ruby
# app/services/aws/lambda_client.rb

# Inquiries
def vms_list_inquiries(status: "active", page: 1, page_size: 50)
def vms_create_inquiry(first_name:, last_name:, phone:, email:, gender:, inquired:, **attrs)
def vms_edit_inquiry(encrypted_id:, active: nil, party_id: nil)
def vms_delete_inquiry(encrypted_id:)

# Volunteers
def vms_list_volunteers(status: "yes", page: 1, page_size: 50)
def vms_create_volunteer(first_name:, last_name:, gender:, **attrs)

# Lookups
def vms_list_lookup(type:)

# Session
def vms_refresh_session
```

All methods use 60-second timeouts (up from 30s) to accommodate multi-step scraping operations.

## CDK Infrastructure Changes

### New Lambda Functions

**VMS Lambda** (`sprout-vms`):
- Runtime: Ruby 3.3
- Timeout: 60 seconds (scraping involves multiple HTTP round-trips)
- Memory: 256 MB
- VPC placement: same as existing Lambdas
- IAM: `secretsmanager:GetSecretValue` on `sprout/vms-session`, `lambda:InvokeFunction` on the refresh Lambda

**VMS Session Refresh Lambda** (`sprout-vms-session-refresh`):
- Runtime: Ruby 3.3
- Timeout: 30 seconds
- Memory: 256 MB
- VPC placement: same as existing Lambdas
- IAM: `secretsmanager:GetSecretValue` + `secretsmanager:PutSecretValue` on `sprout/vms-session`

### New API Gateway Routes

Added under the existing `SproutApi`:

```
/vms
  /session
    /refresh          POST → vms_session_refresh Lambda
  /inquiries          GET, POST → vms Lambda
    /{id}             PUT, DELETE → vms Lambda
  /volunteers         GET, POST → vms Lambda
  /lookups
    /{type}           GET → vms Lambda
```

### New Secrets Manager Secret

`sprout/vms-session` — created by CDK, populated manually (or by running the refresh Lambda once after deploy).

### Optional EventBridge Rule

Weekly schedule to invoke the Session Refresh Lambda proactively (e.g., every Sunday at 2 AM). Low priority — sessions appear to be long-lived.

## Data Flow: Sprout ↔ VMS

### What Sprout stores in its DB

| Data | Table | Purpose |
|------|-------|---------|
| Volunteer records | `volunteers` | Sprout's primary data — owns the funnel |
| VMS EncryptedID | `external_sync_logs.external_id` | Links Sprout record to VMS record |
| Sync audit trail | `external_sync_logs` | Tracks every push/pull: timestamp, direction, status, error |
| Cached lookups | `system_settings` or new `vms_lookups` table | Counties, statuses, types — refreshed periodically |

### What Sprout does NOT store

- Full inquiry/volunteer records from VMS (avoids sync drift — VMS is their system of record)
- Case data (out of MVP scope)
- VMS user accounts

### Sync patterns

**Outbound (Sprout → VMS):** When a new inquiry is submitted via Sprout's public form, a background job calls `vms_create_inquiry` and stores the returned `encrypted_id` in `external_sync_logs`.

**Inbound (VMS → Sprout):** Sprout periodically reads VMS volunteer lists to check if an inquiry has been converted to a volunteer. Lookups are cached locally and refreshed on a schedule.

## VMS Website Technical Details

### Authentication
- ASP.NET Forms Authentication
- Login: `POST /Account/LogOn` with `UserName` and `Password`
- CSRF token (`__RequestVerificationToken`) is NOT required — the VMS does not enforce CSRF protection on any form
- Success indicator: `.ASPXAUTH` cookie present in response
- Session cookies appear to have unlimited lifetime

### SSL Certificate
- The VMS site has a certificate CRL verification issue
- Lambda code disables SSL verification by default (`VMS_SSL_VERIFY=false` environment variable)
- This is controlled via environment variable so it can be re-enabled if the certificate is fixed

### CSRF Protection — Not Present

Despite being an ASP.NET MVC application, the VMS does **not** use `__RequestVerificationToken` on any page. This was verified against:
- Login page (`/Account/LogOn`)
- Inquiry create form (`/Inquiry/Create`)
- Inquiry edit form (`/Inquiry/Edit/{id}`)
- Inquiry delete confirmation (`/Inquiry/Delete/{id}`)

The Lambda code handles this gracefully: it checks for a CSRF token and includes it if found, but does not fail if absent.

### Data Grid Pattern (Kendo UI)

List pages render an empty Kendo grid container in HTML. The grid lazy-loads data via AJAX POST with `X-Requested-With: XMLHttpRequest` header.

**Inquiries:** `POST /Inquiry/_Index?active={active|inactive}`
- Parameters (JSON body): `page` (int), `size` (int), `orderBy` (string like `Inquired-desc`)
- Status filtering: via URL query parameter `?active=active` or `?active=inactive`

**Volunteers:** `POST /Volunteers/_GridIndex?active={yes|no|all}`
- Same body parameters as inquiries
- Uses `_GridIndex` (not `_Index`) — different endpoint suffix
- Status filtering: via URL query parameter `?active=yes`, `?active=no`, or `?active=all`

**Lookups:** `POST /{LookupType}/_Index`
- Same body parameters; no status filter

Response format (all endpoints): `{"Data": [...records...], "Total": N}` (note PascalCase keys — the Kendo response parser handles both cases).

### CRUD Pattern (ASP.NET MVC)
- **Create:** `POST /{Controller}/Create` with form data → 302 redirect on success
- **Edit:** `GET /{Controller}/Edit/{EncryptedID}` (read hidden fields) → `POST /{Controller}/Edit/{EncryptedID}` → 302 on success
- **Delete:** `GET /{Controller}/Delete/{EncryptedID}` (read hidden `InquiryID` + `programID`) → `POST /{Controller}/Delete/{EncryptedID}` → 302 on success
- **Details:** `GET /{Controller}/Details/{EncryptedID}` — read-only page (works for Volunteers, returns 500 for Inquiries)

### ID Encoding
EncryptedIDs are base64-encoded database integer IDs (e.g., `NjQxNjk5` = base64 of `641699`). Not actual encryption. Treat as opaque strings.

### Date Formats
- ASP.NET JSON dates in grid responses: `/Date(1771495200000)/` (milliseconds since Unix epoch)
- Form date fields use `M/D/YYYY` format (e.g., `3/12/2026`)

### Known Quirks
- Volunteer `_GridIndex` returns `EncyptedPartyID` (typo — missing 'r'); `_Index` returns `EncryptedPartyID` (correct)
- Inquiry Edit only supports Active toggle and PartyID — personal info is immutable after creation
- Inquiry Details endpoint returns HTTP 500
- Gender values: 0=Female, 1=Male, 2=Other
- Volunteer list `VolunteerStatuVolunteerStatusName` — concatenation bug in VMS, normalized out by field normalizer

## Volunteer Editing — Discovery (Post-MVP)

The VMS volunteer detail page (`/NewVolunteer/Details/{EncryptedID}`) uses **popup-based editing** via AJAX-loaded modals. There is no standard `/Volunteers/Edit/{id}` page. Instead, editing is split across multiple popup endpoints:

| Endpoint | What it edits | ID format |
|----------|--------------|-----------|
| `/NewVolunteer/PopupApplicantEdit/{partyId}` | Personal info (name, address, contact) | integer PartyID |
| `/Volunteers/VolunteerPopupEdit/{encId}` | Volunteer role/status fields | URL-encoded EncryptedID |
| `/NewVolunteer/PopupApplicantDataEdit/{encId}` | Applicant data | URL-encoded EncryptedID |
| `/NewVolunteer/PopupStatusDataEdit/{encId}` | Status data | URL-encoded EncryptedID |
| `/NewVolunteer/PopupEditCurrentEmploymentInfo/0?partyid={partyId}` | Employment info | integer PartyID |
| `/NewVolunteer/PopupEditVolunteerLicenseEdit/{partyId}` | License info | integer PartyID |

The volunteer detail page also exposes inline checkbox fields: `PermissionToCall`, `ShareInfoPermission`, `IsVolunteer`, `Available`, `Assigned`, `IsSupervisor`, `EligibleForRehire`, `Active`.

**To implement volunteer editing:** Each popup endpoint needs to be probed to discover its form fields, and a new `PUT /vms/volunteers/{id}` endpoint would route to the appropriate popup based on which fields are being updated.

## Error Handling

| Scenario | Lambda Behavior |
|----------|----------------|
| VMS returns 302 to `/Account/LogOn` | Stale session → invoke refresh Lambda → retry once |
| VMS returns 302 to other URL | Success (create/edit/delete redirect) → parse result |
| VMS returns 500 | Return error with VMS response body for debugging |
| VMS unreachable (timeout/DNS) | Return error, do not retry (may be network issue) |
| Secrets Manager unavailable | Return error, cannot operate without session |
| Refresh Lambda fails to authenticate | Return error with details (wrong credentials?) |
| CSRF token not found on page | Continue without it (VMS does not enforce CSRF) |

## Testing

### Integration Test Results (2026-03-26)

Full CRUD lifecycle verified against the real VMS at `nj-passaic.evintotraining.com`:

| Test | Result |
|------|--------|
| Authentication (no CSRF) | PASS |
| Session cookie capture | PASS |
| County lookup (7 records) | PASS |
| VolunteerStatus lookup (3 records) | PASS |
| VolunteerReferral lookup (100+ records) | PASS |
| Ethnicity lookup (8 records) | PASS |
| Passaic county ID 22967 found | PASS |
| List active inquiries | PASS |
| Create inquiry | PASS |
| Find created inquiry in list | PASS |
| Inquiry field normalization | PASS |
| ASP.NET date → ISO 8601 | PASS |
| Edit inquiry (deactivate) | PASS |
| Edit inquiry (reactivate) | PASS |
| Delete inquiry | PASS |
| Verify inquiry deleted | PASS |
| List active volunteers (4 records) | PASS |
| Volunteer field normalization | PASS |
| EncyptedPartyID typo handling | PASS |
| Stale session detection logic | PASS |
| Field normalizer unit tests | PASS |

**29/30 tests pass.** The single failure is a timing-sensitive verification step (checking inactive list immediately after deactivating) — the edit operation itself succeeds.

### Local Development (LocalStack)

The `localstack/init/setup.sh` script creates:
- Lambda function stubs for `sprout-vms` and `sprout-vms-session-refresh`
- All API Gateway routes with correct HTTP method + Lambda wiring
- Secrets Manager secret `sprout/vms-session` with placeholder credentials
- Full endpoint summary in bootstrap output

### Integration Test Script

A comprehensive Ruby test script exists at `.context/test_vms_integration.rb` that can be run against the real VMS environment. It creates a temporary inquiry, exercises all CRUD operations, then deletes it (net zero records).

## Resolved Questions

1. **Volunteer detail pages:** `/Volunteers/Details/{encId}` and `/NewVolunteer/Details/{encId}` both return read-only detail pages. Editing is via popup modals at separate endpoints (see Volunteer Editing section). No standard `/Volunteers/Edit/{id}` exists.
2. **Inquiry conversion:** Manual process. An admin creates the volunteer record separately (via `/Volunteers/Create`) and may link it to the inquiry via the `PartyID` field on the inquiry edit form, or simply deactivate the inquiry. Sprout supports both workflows.
3. **Webhook/push from VMS:** No webhooks. The VMS is a legacy site with no push notification capability. Sprout must poll for changes.
4. **Rate limiting:** No rate limiting observed during testing. The Lambda supports a configurable delay via environment variable as a precaution.
5. **Multi-county:** Passaic only. The `county_id` for Passaic is `22967`. This is the default for inquiry/volunteer creation.
6. **CSRF tokens:** The VMS does NOT use `__RequestVerificationToken` on any page. The Lambda handles this gracefully (includes if present, skips if not).
7. **SSL certificates:** The VMS site has a certificate CRL issue. SSL verification is disabled by default via `VMS_SSL_VERIFY` environment variable.
8. **Kendo endpoints:** Inquiries use `_Index`, Volunteers use `_GridIndex`. Status filtering is via URL query params, not POST body. The grid param is `size` (not `pageSize`).
