# Mailchimp SMS integration

Manual SMS follows this path:

`Volunteer list / profile message dialog → Sms::MailchimpOutbound → Mailchimp::TransactionalClient → Mailchimp Transactional (Mandrill)`

Rails calls Mandrill directly (no API Gateway / Lambda required for SMS). The client uses
`POST https://mandrillapp.com/api/1.4/messages/send-sms` with the nested `message.sms` payload
(recipient array, approved sender, message text, and consent type).

Use a **Mailchimp Transactional** API key stored as `mandrill.api_key` in the encrypted credentials, not a Marketing API key.

The implementation follows [Mailchimp's official OpenAPI schema](https://github.com/mailchimp/mailchimp-client-lib-codegen/blob/main/spec/transactional.openapi.json), specifically `MessagesSendSmsRequest` and `MessagesSmsMessage`.

## Configuration

Secrets live in `config/credentials.yml.enc` and are unlocked by `config/master.key`
(the same key used for Google sign-in). Obtain `master.key` from Dr. DePasquale via
1Password and place it in `config/` before starting the app. Then edit the vault:

```sh
bin/rails credentials:edit
```

```yaml
mandrill:
  api_key: your_transactional_key
  sms_from: "+1..."
  from_email: your_verified_sender_address
```

`api_key` is the Mailchimp Transactional key. `sms_from` is the approved sending
number or sender ID. `from_email` is the verified From address for transactional
email. Do not put these values in a `.env` file.

### Local and production accounts

The `mandrill.api_key` value selects the Mandrill account. Localhost does not
automatically select a sandbox, and a browser's hostname does not change the key.
Use the testing account's key and approved sending number in the local credentials
file. Production uses its own `config/credentials.yml.enc` (or the host's
`RAILS_MASTER_KEY`) with the production account's key and sender, for both web and
job processes. Do not place both accounts' secrets in the local credentials file.

A Marketing API key is a different credential. It is not read for SMS or email.

Mailchimp's [email test API keys](https://mailchimp.com/developer/transactional/docs/fundamentals/#test-mode)
simulate email sends without inbox delivery. Switching the Mailchimp browser UI to
test mode does not change requests sent with a live API key. For a real phone test,
use an SMS-enabled testing account with an approved sender and credits, and restrict
the recipients to the agreed **Sprout Testing** contacts. Automated RSpec/Cucumber
tests simulate responses and do not need a live account. The normal staff composer
does not filter volunteers by Mailchimp audience tags.

After editing credentials, restart the web container so Rails reloads them:

```bash
docker compose up -d --force-recreate web
docker compose exec web bin/rails db:migrate
```

The production image does not include `config/master.key`. Provide `RAILS_MASTER_KEY`
through the deployment platform and restart its web and job processes.
`docker-compose.yml` is the local development setup, not the production deployment
configuration.

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

Seeds include an editable **General SMS follow-up** template with a manual trigger.
For an existing database, add just this starter with
`docker compose exec web bin/rails runner db/seeds/sms_templates.rb`.
This creates no messages and preserves edits or an inactive setting on later runs.
If the composer only offers **Custom message**, there are no active SMS templates;
email templates do not appear there. **Create SMS template** opens the editor with
SMS and Manual already selected. Save it as Active, then reopen the Volunteers page.

Bulk SMS also supports templates. Its draft retains merge fields until sending,
then fills them in separately for each selected volunteer. The final personalized
length is checked per recipient. The result counts successes and failures, including
recipients whose expanded messages are too long. Changing recipients clears the
individual draft, template choice and consent. Failed single sends retain the draft.

The shared SMS/note dialog changes both its POST URL and the matching per-form
CSRF token when it opens for an individual or a group. SMS, notes and bulk browser
features explicitly enable Rails CSRF protection, which is otherwise off in test.
Request coverage also confirms that missing tokens and tokens for another action,
volunteer or browser session are rejected before a message is sent.

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

### Enabling SMS

| Setting | Where | Purpose |
|---|---|---|
| `mandrill.api_key` | Encrypted credentials | Mailchimp Transactional key |
| `mandrill.sms_from` | Encrypted credentials | Approved sending number / sender ID |
| `SPROUT_SMS_MAILCHIMP_ENABLED=true` | Environment | Turns outbound SMS on after the vault is configured |

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
`Mailchimp::TransactionalClient` (`messages/send`). Store `mandrill.api_key` and
`mandrill.from_email` in the encrypted credentials, then set
`SPROUT_EMAIL_MAILCHIMP_ENABLED=true`.

Set the application link in **Admin settings → Application email**. That link is
included when a volunteer checks in. The check-in email is not sent without it.
A failed inquiry confirmation is logged and the public thanks message stays in
place. A failed check-in email keeps the attendance record and shows an error
instead of claiming the email was sent.
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
