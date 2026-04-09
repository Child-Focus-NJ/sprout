# VMS API

The VMS API provides programmatic access to the legacy Volunteer Management System (Optima/eVinto). It supports managing inquiries, volunteers, and lookup data.

## Base URL

```
https://{api-id}.execute-api.us-east-1.amazonaws.com/v1
```

In local development (LocalStack), the base URL is written to a file by the bootstrap script and resolved automatically by `Aws::LambdaClient`.

## Authentication

The API handles VMS authentication automatically. Session cookies are managed via AWS Secrets Manager and refreshed transparently when they expire. No authentication headers are required from the caller.

If you need to force a session refresh (e.g., after a credential change), see [Refresh Session](#refresh-session).

## Errors

All error responses follow this format:

```json
{
  "error": "Description of what went wrong"
}
```

| Status Code | Meaning |
|-------------|---------|
| `200` | Success |
| `201` | Created |
| `400` | Bad request (missing required parameter) |
| `404` | Resource not found or unknown lookup type |
| `405` | HTTP method not allowed for this endpoint |
| `422` | Unprocessable entity (VMS rejected the form submission) |
| `500` | Internal server error |

## Pagination

List endpoints return paginated results:

```json
{
  "data": [ ... ],
  "total": 142,
  "page": 1,
  "page_size": 50
}
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `page` | `1` | Page number (1-indexed) |
| `page_size` | `50` | Records per page |
| `order_by` | Varies | Sort field and direction, e.g. `LastName-asc` |

## Field Conventions

- All response field names are **snake_case** (converted from VMS PascalCase)
- Dates are returned in **ISO 8601** format (`2026-03-15`), converted from ASP.NET `/Date(ms)/` format
- Dates in request bodies use **MM/DD/YYYY** format (what the VMS expects)
- IDs prefixed with `encrypted_` are base64-encoded identifiers used by the VMS for URL routing

---

# Inquiries

Inquiries represent potential volunteers who have expressed interest but haven't yet been converted to active volunteer records.

## List Inquiries

```
GET /vms/inquiries
```

**Parameters**

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `status` | string | `active` | Filter: `active` or `inactive` |
| `page` | integer | `1` | Page number |
| `page_size` | integer | `50` | Results per page |
| `order_by` | string | `Inquired-desc` | Sort field and direction |

**Response** `200 OK`

```json
{
  "data": [
    {
      "inquiry_id": 12345,
      "encrypted_id": "NzIxNzE0Mg==",
      "first_name": "Jane",
      "last_name": "Smith",
      "email": "jane@example.com",
      "phone": "555-0100",
      "inquired": "2026-03-15",
      "active": true,
      "party_id": 67890,
      "gender": "Female",
      "address": "123 Main St",
      "city": "Paterson",
      "state": "NJ",
      "zip": "07501"
    }
  ],
  "total": 142,
  "page": 1,
  "page_size": 50
}
```

## Create Inquiry

```
POST /vms/inquiries
```

**Request Body**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `first_name` | string | Yes | |
| `last_name` | string | Yes | |
| `phone` | string | Yes | |
| `email` | string | Yes | |
| `gender` | integer | Yes | `0` = Not specified, `1` = Male, `2` = Female |
| `inquired` | string | Yes | Date in `MM/DD/YYYY` format |
| `address` | string | No | |
| `address2` | string | No | |
| `city` | string | No | |
| `state` | string | No | |
| `zip` | string | No | |
| `county_id` | integer | No | Defaults to `22967` (Passaic County) |

**Example**

```json
{
  "first_name": "Jane",
  "last_name": "Smith",
  "phone": "555-0100",
  "email": "jane@example.com",
  "gender": 2,
  "inquired": "03/15/2026"
}
```

**Response** `201 Created`

```json
{
  "success": true,
  "encrypted_id": "NzIxNzE0Mg=="
}
```

The `encrypted_id` is retrieved by matching the newly created record against the inquiry list. It may be `null` if the match fails (the record is still created).

## Edit Inquiry

```
PUT /vms/inquiries/{encrypted_id}
```

The VMS edit form only exposes two editable fields. All other fields are preserved from the existing record.

**Request Body**

| Field | Type | Description |
|-------|------|-------------|
| `active` | boolean | `true` or `false` to activate/deactivate |
| `party_id` | integer | Links the inquiry to a volunteer record |

Both fields are optional. Include only the fields you want to change.

**Example**

```json
{
  "active": false
}
```

**Response** `200 OK`

```json
{
  "success": true
}
```

## Delete Inquiry

```
DELETE /vms/inquiries/{encrypted_id}
```

Permanently deletes the inquiry from the VMS.

**Response** `200 OK`

```json
{
  "success": true
}
```

---

# Volunteers

Volunteer records represent individuals who have been onboarded into the VMS.

## List Volunteers

```
GET /vms/volunteers
```

**Parameters**

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `status` | string | `yes` | Filter: `yes` (active), `no` (inactive), `all` |
| `page` | integer | `1` | Page number |
| `page_size` | integer | `50` | Results per page |
| `order_by` | string | `LastName-asc` | Sort field and direction |

**Response** `200 OK`

```json
{
  "data": [
    {
      "party_id": 67890,
      "encrypted_party_id": "NzIxNzE0Mg==",
      "first_name": "Jane",
      "last_name": "Smith",
      "gender": "Female",
      "home_email": "jane@example.com",
      "work_email": null,
      "best_email": "jane@example.com",
      "cell_phone": "555-0100",
      "home_phone": null,
      "best_phone": "555-0100",
      "address": "123 Main St",
      "city": "Paterson",
      "state": "NJ",
      "zip": "07501",
      "active": true
    }
  ],
  "total": 305,
  "page": 1,
  "page_size": 50
}
```

## Create Volunteer

```
POST /vms/volunteers
```

**Request Body**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `first_name` | string | Yes | |
| `last_name` | string | Yes | |
| `gender` | integer | Yes | `0` = Not specified, `1` = Male, `2` = Female |
| `middle_name` | string | No | |
| `aka_name` | string | No | Also known as |
| `ssn` | string | No | Social security number |
| `address` | string | No | |
| `city` | string | No | |
| `state` | string | No | |
| `zip` | string | No | |
| `county_id` | integer | No | Defaults to `22967` (Passaic County) |
| `hispanic` | boolean | No | |
| `ethnicity_id` | integer | No | See [Lookups](#list-lookup-values) |
| `marital_status_id` | integer | No | |
| `birthdate` | string | No | `MM/DD/YYYY` format |
| `home_email` | string | No | |
| `work_email` | string | No | |
| `best_email` | string | No | |
| `home_phone` | string | No | |
| `cell_phone` | string | No | |
| `work_phone` | string | No | |
| `best_phone` | string | No | |
| `permission_to_call` | boolean | No | Defaults to `true` |
| `share_info_permission` | boolean | No | Defaults to `true` |

**Example**

```json
{
  "first_name": "Jane",
  "last_name": "Smith",
  "gender": 2,
  "home_email": "jane@example.com",
  "cell_phone": "555-0100",
  "birthdate": "05/20/1990"
}
```

**Response** `201 Created`

```json
{
  "success": true
}
```

## Edit Volunteer

Not yet implemented. The VMS uses popup-based AJAX modals for volunteer editing at these endpoints:

| Endpoint | Content |
|----------|---------|
| `/NewVolunteer/PopupApplicantEdit/{partyId}` | Personal info (name, SSN, address) |
| `/NewVolunteer/PopupApplicantContactEdit/{partyId}` | Contact info (phones, emails) |

These endpoints are known to exist and return editable form HTML. Implementing support is feasible with the existing infrastructure but has not been built yet.

---

# Lookups

Lookup endpoints return reference data used to populate dropdowns and validate IDs in create/edit requests.

## List Lookup Values

```
GET /vms/lookups/{type}
```

**Path Parameters**

| Name | Description |
|------|-------------|
| `type` | One of the lookup types listed below |

**Lookup Types**

| Type | Description |
|------|-------------|
| `County` | Geographic counties |
| `VolunteerStatus` | Volunteer statuses |
| `VolunteerStatusReason` | Reasons for status changes |
| `VolunteerType` | Categories of volunteers |
| `VolunteerReferral` | How volunteers heard about the program |
| `InquiryEvent` | Events that generated inquiries |
| `VolunteerActivityType` | Types of volunteer activities |
| `VolunteerContactType` | Contact log types |
| `EmploymentStatus` | Employment statuses |
| `Ethnicity` | Ethnicity categories |
| `LanguageType` | Languages spoken |
| `Degree` | Education degrees |
| `EducationType` | Education types |

**Response** `200 OK`

```json
{
  "data": [
    { "id": 22967, "encrypted_id": "NzIxNw==", "name": "Passaic", "active": true },
    { "id": 22968, "encrypted_id": "NzIxOA==", "name": "Bergen", "active": true }
  ],
  "total": 21
}
```

All lookup types are normalized to a consistent `{ id, encrypted_id, name, active }` shape regardless of the underlying VMS field names.

**Error** `404 Not Found` — invalid type

```json
{
  "error": "Unknown lookup type: InvalidType",
  "valid_types": ["County", "VolunteerStatus", "..."]
}
```

---

# Session

Session management is handled automatically. These endpoints are for debugging and manual intervention.

## Refresh Session

```
POST /vms/session/refresh
```

Forces a new login to the VMS and writes fresh session cookies to Secrets Manager. This is called automatically by the VMS Lambda when it detects an expired session (HTTP 302 redirect to login page).

**Request Body** — empty `{}`

**Response** `200 OK`

```json
{
  "success": true,
  "cookies": {
    "ASP.NET_SessionId": "abc123",
    ".ASPXAUTH": "def456..."
  },
  "refreshed_at": "2026-03-26T14:30:00Z"
}
```

**Error** `401 Unauthorized` — credentials in Secrets Manager are wrong

```json
{
  "success": false,
  "error": "Authentication failed — .ASPXAUTH cookie not present. Check credentials."
}
```

---

# Rails Client

The `Aws::LambdaClient` class wraps all VMS endpoints as Ruby methods. It handles URL resolution, JSON serialization, and error raising.

```ruby
client = Aws::LambdaClient.new
```

## Methods

### Inquiries

```ruby
# List inquiries (paginated)
client.vms_list_inquiries(status: "active", page: 1, page_size: 25)

# Create an inquiry
client.vms_create_inquiry(
  first_name: "Jane",
  last_name: "Smith",
  phone: "555-0100",
  email: "jane@example.com",
  gender: 2,
  inquired: "03/15/2026"
)

# Edit an inquiry
client.vms_edit_inquiry(encrypted_id: "NzIxNzE0Mg==", active: false)

# Delete an inquiry
client.vms_delete_inquiry(encrypted_id: "NzIxNzE0Mg==")
```

### Volunteers

```ruby
# List volunteers (paginated)
client.vms_list_volunteers(status: "yes", page: 1, page_size: 25)

# Create a volunteer
client.vms_create_volunteer(
  first_name: "Jane",
  last_name: "Smith",
  gender: 2,
  home_email: "jane@example.com",
  cell_phone: "555-0100"
)
```

### Lookups

```ruby
# Fetch reference data
counties = client.vms_list_lookup(type: "County")
statuses = client.vms_list_lookup(type: "VolunteerStatus")
```

### Session

```ruby
# Force session refresh (rarely needed)
client.vms_refresh_session
```

## Error Handling

All methods raise `Aws::LambdaClient::LambdaError` on non-2xx responses:

```ruby
begin
  client.vms_create_inquiry(first_name: "Jane", ...)
rescue Aws::LambdaClient::LambdaError => e
  Rails.logger.error("VMS error: #{e.message}")
end
```

---

# Configuration

## Secrets Manager

The secret `sprout/vms-session` must contain:

```json
{
  "base_url": "https://nj-passaic.evintotraining.com",
  "username": "<vms-username>",
  "password": "<vms-password>",
  "cookies": {
    "ASP.NET_SessionId": "<auto-managed>",
    ".ASPXAUTH": "<auto-managed>"
  },
  "refreshed_at": "<auto-managed>"
}
```

Set `base_url`, `username`, and `password` manually. The `cookies` and `refreshed_at` fields are managed automatically by the Session Refresh Lambda.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `AWS_REGION` | `us-east-1` | AWS region for SDK clients |
| `AWS_ENDPOINT_URL` | — | LocalStack endpoint for local development |
| `VMS_SSL_VERIFY` | `false` | SSL certificate verification (disabled due to VMS certificate issues) |
| `API_GATEWAY_URL` | — | API Gateway base URL (production) |
| `API_GATEWAY_URL_FILE` | — | Path to file containing API Gateway URL (local dev) |
