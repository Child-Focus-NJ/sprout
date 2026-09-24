# Mailchimp email integration

Staff can use **Send Email** from the volunteer list or profile to compose a subject and plain-text message. Inquiry confirmations, attendance application emails, and **Send Application** use the same delivery service:

`Rails → Aws::LambdaClient → API Gateway → mailchimp_realtime Lambda → Mailchimp Transactional`

The Lambda calls `https://mandrillapp.com/api/1.4/messages/send` with the configured `from_email`, one recipient, subject, and text. It validates the recipient, status, and provider ID in the response. The payload follows [Mailchimp's OpenAPI schema](https://github.com/mailchimp/mailchimp-client-lib-codegen/blob/main/spec/transactional.openapi.json). Provider credentials stay in the Lambda environment.

## Application link

1. Sign in as an administrator and open **Admin → Application email settings**.
2. Enter the application URL in **Application link** and save it.
3. Use **Send Application** on a volunteer profile, or check in a volunteer for an information session.

The URL is stored in `SystemSetting` and read for each new application email. Updating it requires no code change or restart. Blank values are allowed until the application is ready; application sending then displays a configuration error. Only complete HTTP or HTTPS URLs without embedded credentials are accepted. The saved setting records which administrator last updated it.

The application email contains a brief introduction and the configured link. Existing communication records retain the content originally sent. Saving a link does not send emails to previously checked-in volunteers; staff can use **Send Application** for them.

## Provider configuration

Run the database migration, and set these values in your untracked `.env` for local Docker development:

```dotenv
SPROUT_EMAIL_MAILCHIMP_ENABLED=true
MAILCHIMP_API_KEY=your_transactional_api_key
MAILCHIMP_EMAIL_FROM=your_verified_sender_address
```

These are placeholders. Use a Mailchimp Transactional key and an address on your verified/authenticated sending domain. See [Mailchimp's first email guide](https://mailchimp.com/developer/transactional/guides/send-first-email/) for account setup. SMS configuration remains independent.

```bash
docker compose up -d db
docker compose up -d --force-recreate localstack
docker compose up -d web
```

Wait for `Sprout LocalStack Bootstrap Complete` in LocalStack logs. The web entrypoint runs migrations. For CDK deployments, provide `MailchimpApiKey` and `MailchimpEmailFrom`; configure `SPROUT_EMAIL_MAILCHIMP_ENABLED` and the gateway URL on Rails separately.

## Outcomes

| Provider outcome | Communication status | Application sent date |
|---|---|---|
| `sent` | `sent`, with provider ID and sent time | Set; stage advances unless already submitted or inactive |
| `queued` or `scheduled` | `queued`, with provider ID | Unchanged |
| `rejected` or `invalid` | `failed`, with rejection details | Unchanged |
| Definite configuration/gateway rejection | `failed` if a provider attempt was recorded | Unchanged |
| Timeout or unrecognized result | `pending`, with an uncertainty warning | Unchanged |

Disabled sending, invalid input, and a missing application link are rejected before a send attempt. Inquiry and attendance records are retained when their automatic email fails. Manual compose errors preserve the draft. History includes the recipient snapshot, subject, body, staff sender when applicable, error, and provider ID.

Application attempts are recorded under a volunteer lock before contacting the provider. Pending, queued, or sent attempts block another application send. Definite failures allow another attempt. Uncertain outcomes require checking Mailchimp activity before any resend; automatic retries and delivery webhooks are not implemented. Queued results do not later update themselves in Sprout. Existing template-based reminders and audience sync are outside this change.

## Verification

The automated tests simulate provider responses and do not deliver real email. After preparing the test database and assets, run:

```bash
docker compose run --rm --no-deps --entrypoint bundle \
  -e RAILS_ENV=test \
  -e DATABASE_URL=postgres://sprout:sprout@db:5432/sprout_test web \
  exec rspec

docker compose run --rm --no-deps --entrypoint bundle \
  -e RAILS_ENV=test \
  -e DATABASE_URL=postgres://sprout:sprout@db:5432/sprout_test web \
  exec cucumber features/03_email_automation.feature features/03_manual_email.feature \
  features/06_application_process.feature features/09_sign_in_attendance.feature
```

For a live test, configure the real provider account, create a test volunteer using an inbox you control, and use **Send Email**. Inspect both the inbox and Mailchimp activity. A `sent` response confirms provider acceptance, not final inbox delivery.
