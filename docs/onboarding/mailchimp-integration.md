# Mailchimp SMS integration

Manual SMS follows this path:

`Volunteer list / profile message dialog → Sms::MailchimpOutbound → Mailchimp::TransactionalClient → Mailchimp Transactional (Mandrill)`

Rails calls Mandrill directly (no API Gateway / Lambda required for SMS). The client uses
`POST https://mandrillapp.com/api/1.4/messages/send-sms` with the nested `message.sms` payload
(recipient array, approved sender, message text, and consent type).

Use a **Mailchimp Transactional** API key (`MANDRILL_API_KEY`), not a Marketing API key.
`MAILCHIMP_API_KEY` / `MAILCHIMP_SMS_FROM` are also accepted as fallbacks for local setup.

The implementation follows [Mailchimp's official OpenAPI schema](https://github.com/mailchimp/mailchimp-client-lib-codegen/blob/main/spec/transactional.openapi.json), specifically `MessagesSendSmsRequest` and `MessagesSmsMessage`.

## Configuration

Start with [the local environment template](../../.env.example) or
[the production environment template](../../.env.production.example). These files
contain placeholders only; keep your actual `.env` untracked.

### Local and production accounts

The server's `MANDRILL_API_KEY` selects the Mandrill account. Localhost does not
automatically select a sandbox, and a browser's hostname does not change the key.
Use the testing account's key and approved sending number in the local `.env`.
Set the production account's key and sender in the production host's secret store,
for both web and job processes. Use the same variable names in both environments.
Do not place both accounts' secrets in the local file.

`MAILCHIMP_API_KEY` is normally the separate **Marketing** credential used by the
testing-tag inspection scripts. Always set `MANDRILL_API_KEY` explicitly when using
both products; the legacy fallback is only for installations that previously
stored a Transactional key under `MAILCHIMP_API_KEY`.

Mailchimp's [email test API keys](https://mailchimp.com/developer/transactional/docs/fundamentals/#test-mode)
simulate email sends without inbox delivery. Switching the Mailchimp browser UI to
test mode does not change requests sent with a live API key. For a real phone test,
use an SMS-enabled testing account with an approved sender and credits, and restrict
the recipients to the agreed **Sprout Testing** contacts. Automated RSpec/Cucumber
tests simulate responses and do not need a live account. The normal staff composer
does not filter volunteers by Mailchimp audience tags.

After updating the local `.env`, recreate the web container so Compose refreshes
its configuration:

```bash
docker compose up -d --force-recreate web
docker compose exec web bin/rails db:migrate
```

The production image excludes `.env` files. Inject runtime secrets through the
deployment platform and restart its web/job processes. `docker-compose.yml` is the
local development setup, not the production deployment configuration.

### Frontend flow

1. Open **Volunteers**, click a volunteer's name, and choose **Send SMS** in Actions.
   The list's phone icon opens the same composer directly.
2. Leave **SMS template** on **Custom message**, or choose an active SMS template.
   Individual templates load with merge fields filled in for that volunteer.
   The resulting message is editable, with a 320-character limit and counter.
3. Select the SMS consent that the recipient has already provided and press **Send**.
   The profile's timeline retains the final message, recipient, status and provider ID.
4. **Open full SMS page** provides the same composer at `/volunteers/:id/sms`.
   Both views link to **Open Mailchimp dashboard** and **View Mandrill activity** in
   new tabs. These links use the staff member's browser login, not the API key.

Create reusable templates under **Message Templates → New Template**, choose
**SMS** as the type and keep it **Active**. Supported merge fields include
`{{first_name}}`, `{{last_name}}`, `{{full_name}}`, `{{email}}`, `{{phone}}`,
`{{current_date}}` and `{{organization_name}}`. Templates are stored in Sprout;
this does not import Mailchimp campaign templates.

Bulk SMS also supports templates. Its draft retains merge fields until sending,
then fills them in separately for each selected volunteer. The final personalized
length is checked per recipient. The result counts successes and failures, including
recipients whose expanded messages are too long. Changing recipients clears the
individual draft, template choice and consent. Failed single sends retain the draft.

### Screenshots for PR review

Use fictional volunteers or the agreed testing contacts; keep keys and unrelated
contact details out of screenshots.

1. **Volunteer list → profile:** the volunteer name link and profile Actions with Send SMS.
2. **Custom SMS:** the open dialog showing recipient, custom draft, character count,
   consent selector and Mailchimp dashboard links.
3. **Template SMS:** a selected template with the volunteer's name filled in and
   an edited message. Include the template dropdown and character count.
4. **Send result:** the confirmation banner and the new SMS timeline entry with
   final body, `sent` or `queued` status and provider ID. A `sent` status is provider
   acceptance, not a claim of final handset delivery.
5. **Template management:** an active SMS template with merge fields in the editor.
6. Optional: the full SMS page, missing-phone disabled state, or a failed send with
   its retained draft. For actual delivery evidence, include the received test SMS
   or corresponding Mandrill activity separately from the simulated test screenshots.

### Environment variables

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
| Timeout, provider HTTP 5xx, or unrecognized response | `pending`, with an uncertainty warning | None |

Only a confirmed `sent` result creates a sent timeline note. An accepted send is not proof of delivery. This change does not implement delivery webhooks; final delivery and later queue outcomes must be checked in Mailchimp. Uncertain attempts are not retried automatically, since a retry might duplicate a message. Failed individual sends preserve the message and consent on an error page. Successful sends return to the profile or filtered list that opened the dialog.

The list's bulk SMS action requires consent for every recipient. Its result separately counts sent, queued, uncertain, rejected, and skipped recipients. Review individual timeline records before resending a group with partial success.

## Grouped communication history

The volunteer profile's consolidated timeline shows existing email and SMS `Communication` records together, newest first, including status, message, timestamp, staff sender, recipient, provider ID, and failure details where available.

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

## Automatic transactional email

Inquiry confirmations and application emails after attendance use
`Email::VolunteerNotifications` → `Email::MailchimpOutbound` →
`Mailchimp::TransactionalClient` (`messages/send`). Add these values to the
untracked root `.env` to enable them:

```dotenv
SPROUT_EMAIL_MAILCHIMP_ENABLED=true
MANDRILL_API_KEY=your_transactional_key
MANDRILL_FROM_EMAIL=your_verified_sender_address
```

Set the application link in **Admin settings → Application email**. Application
emails require a valid link. Missing configuration or sending errors preserve
inquiries and attendance and show an error instead of claiming the email was sent.
A queued or uncertain application attempt blocks another send until its outcome is
known. Reminder emails use the same configured From address.

Mailchimp's [Transactional demo](https://mailchimp.com/help/transactional-email-demo/)
restricts recipients to verified domains too. A `recipient-domain-mismatch`
rejection can occur even when the sender is authenticated and the recipient has
the intended Marketing audience tag. An audience tag does not remove the
Transactional account's sending restrictions. A `sent` API result alone does not
prove inbox receipt.

### Queued application emails

With email enabled and the Solid Queue worker/scheduler running, `RefreshQueuedEmailsJob` checks queued email records with provider IDs every five minutes using Mandrill `messages/info`. A confirmed `sent` result records the provider's send time, adds the staff timeline note once, and advances an eligible volunteer to `application_sent`. Volunteers already applied or inactive keep their stage. Other email purposes do not change the application stage.

Still-queued/scheduled results and unavailable or malformed lookups preserve the queued attempt and block duplicate application sends. Rejected/canceled messages become failed; bounced messages become bounced without advancing the volunteer. This job never resends a message. Pending attempts without a provider ID still require manual investigation, and already-sent emails are not polled for later delivery or bounce events.

The check can also be run without sending anything:

```sh
docker compose exec web bin/rails runner 'RefreshQueuedEmailsJob.perform_now'
```
