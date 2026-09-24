# Mailchimp SMS integration

Manual SMS follows this path:

`Inquiry volunteer list / profile → Sms::MailchimpOutbound → Mailchimp::TransactionalClient → Mailchimp Transactional (Mandrill)`

Rails calls Mandrill directly (no API Gateway / Lambda required for SMS). The client uses
`POST https://mandrillapp.com/api/1.4/messages/send-sms` with the nested `message.sms` payload
(recipient array, approved sender, message text, and consent type).

Use a **Mailchimp Transactional** API key (`MANDRILL_API_KEY`), not a Marketing API key.
`MAILCHIMP_API_KEY` / `MAILCHIMP_SMS_FROM` are also accepted as fallbacks for local setup.

The implementation follows [Mailchimp's official OpenAPI schema](https://github.com/mailchimp/mailchimp-client-lib-codegen/blob/main/spec/transactional.openapi.json), specifically `MessagesSendSmsRequest` and `MessagesSmsMessage`.

## Configuration

| Setting | Where | Purpose |
|---|---|---|
| `SPROUT_SMS_MAILCHIMP_ENABLED=true` | Rails | Explicitly enables outbound SMS |
| `MANDRILL_API_KEY` | Rails | Mailchimp Transactional credential (preferred) |
| `MANDRILL_SMS_FROM` | Rails | Approved sending number / sender ID |
| `MAILCHIMP_API_KEY` | Rails (fallback) | Alternate name for the Transactional key |
| `MAILCHIMP_SMS_FROM` | Rails (fallback) | Alternate name for the sender |

For WSL + Docker, configure the variables in your untracked `.env`:

```dotenv
SPROUT_SMS_MAILCHIMP_ENABLED=true
MANDRILL_API_KEY=
MANDRILL_SMS_FROM=
```

Real sending requires an enabled Transactional account (Owner/Admin), an approved SMS program, and SMS credits. Manager-level Mailchimp users cannot open Mandrill to create keys. See [Mailchimp's prerequisites and consent documentation](https://mailchimp.com/developer/transactional/docs/transactional-sms/).

## Consent and send outcomes

Staff must explicitly select the permission already provided by the volunteer: one informational message, recurring messages with a confirmation, or recurring messages whose confirmation was already sent. Sprout does not infer consent from a phone number or contact preference. The selected consent type, recipient number, message body, staff user, and attempt time are retained on the communication record. US numbers are normalized to E.164; explicit international country codes are preserved.

| Outcome | Sprout status | Sent time |
|---|---|---|
| Sending disabled or input invalid | No send record; visible error | None |
| Provider returns `sent` | `sent`, with provider message ID | Recorded |
| Provider returns `queued` or `scheduled` | `queued`, with provider message ID | None |
| Provider returns `rejected` or `invalid` | `failed`, with provider ID and reason | None |
| Missing configuration or provider rejection | `failed`, with error | None |
| Timeout or unrecognized response | `pending`, with an uncertainty warning | None |

Only a confirmed `sent` result creates a sent timeline note. An accepted send is not proof of delivery. This change does not implement delivery webhooks; final delivery and later queue outcomes must be checked in Mailchimp. Uncertain attempts are not retried automatically, since a retry might duplicate a message. Failed requests preserve the compose draft.

## Grouped communication history

The volunteer profile shows existing email and SMS `Communication` records together, newest first, including status, message, timestamp, staff sender, and SMS provider ID where available. Timeline entries also display their communication status.

Mailchimp automatically logs transactional SMS alongside transactional email in Outbound Activity. Sprout retains the provider ID to cross-reference that activity. This does not import historical Mailchimp activity, marketing campaigns, or replies into Sprout, and does not implement audience-sync actions. Existing records that were marked delivered by the old local fallback are not retroactively verified or rewritten.

## Verification without live credentials

Run from WSL using Docker. These tests explicitly simulate provider responses at network boundaries and do not send real messages:

```bash
docker compose up -d db
docker compose run --rm --no-deps --entrypoint bash \
  -e RAILS_ENV=test \
  -e DATABASE_URL=postgres://sprout:sprout@db:5432/sprout_test web -lc \
  'bin/rails db:test:prepare && bin/rails tailwindcss:build && bundle exec rspec spec/services/sms spec/services/mailchimp'
```

## Marketing campaigns (list in Sprout)

Admins can open **Campaigns** (`/admin/campaigns`) to list recent Mailchimp marketing campaigns via `Mailchimp::MarketingClient` and `MAILCHIMP_API_KEY` (Marketing API key with datacenter suffix, e.g. `-us2`). Sending bulk campaigns still happens in the Mailchimp UI.

## Transactional email (ActionMailer SMTP)

When `MANDRILL_API_KEY` is set, `config/initializers/mailchimp_transactional_smtp.rb` routes ActionMailer through Mandrill SMTP. Manual/application emails use `Email::MailchimpOutbound` → `Mailchimp::TransactionalClient` (`messages/send`).

Additional email env vars:

| Setting | Purpose |
|---|---|
| `SPROUT_EMAIL_MAILCHIMP_ENABLED=true` | Enables outbound transactional email from Sprout |
| `MANDRILL_FROM_EMAIL` / `MAILCHIMP_EMAIL_FROM` | Verified From address |
| `MANDRILL_SMTP_USERNAME` | SMTP username (registered Mandrill email) |
