# Mailchimp SMS integration

Manual SMS follows this path:

`Inquiry volunteer list / profile → Sms::MailchimpOutbound → API Gateway → mailchimp_realtime Lambda → Mailchimp Transactional`

The Lambda uses `POST https://mandrillapp.com/api/1.4/messages/send-sms` and the nested `message.sms` payload, including a recipient array, approved sender, message text, and consent type. The API key is read only from the Lambda's `MAILCHIMP_API_KEY` environment variable. Use a **Mailchimp Transactional** key, not a Marketing API key.

The implementation follows [Mailchimp's official OpenAPI schema](https://github.com/mailchimp/mailchimp-client-lib-codegen/blob/main/spec/transactional.openapi.json), specifically `MessagesSendSmsRequest` and `MessagesSmsMessage`. The [first SMS guide](https://mailchimp.com/developer/transactional/guides/send-first-sms/) still illustrates v1.1 with a scalar recipient; this implementation follows the v1.4 schema's recipient array.

## Configuration

| Setting | Where | Purpose |
|---|---|---|
| `SPROUT_SMS_MAILCHIMP_ENABLED=true` | Rails | Explicitly enables outbound SMS |
| `API_GATEWAY_URL` or `API_GATEWAY_URL_FILE` | Rails | Existing gateway location; Docker uses the generated URL file |
| `MAILCHIMP_API_KEY` | Lambda | Mailchimp Transactional credential; never put it in source control |
| `MAILCHIMP_SMS_FROM` | Lambda | Sending number or sender ID approved on the Mailchimp account |

For WSL + Docker, configure the variables in your untracked `.env`. Credential placeholder:

```dotenv
SPROUT_SMS_MAILCHIMP_ENABLED=true
MAILCHIMP_API_KEY=MAILCHIMP_API_KEY
MAILCHIMP_SMS_FROM=
```

`MAILCHIMP_API_KEY` above is a placeholder, not a working credential. The sender is deliberately blank; obtain the approved value from the account. Real sending requires an enabled Transactional account, approved SMS program, and SMS credits. See [Mailchimp's prerequisites and consent documentation](https://mailchimp.com/developer/transactional/docs/transactional-sms/).

Docker Compose passes the provider configuration to LocalStack, which packages the real `lambdas/mailchimp_realtime` source. Restart LocalStack after changing its code or configuration:

```bash
docker compose up -d db
docker compose up -d --force-recreate localstack
docker compose up -d web
```

Wait for `Sprout LocalStack Bootstrap Complete` in its logs before sending. The other local integrations still use their existing stubs. The Mailchimp email/member/tag actions return `501 Not Implemented`; they do not claim success.

For CDK deployments, the Lambda stack accepts `MailchimpApiKey` (a masked CloudFormation parameter) and `MailchimpSmsFrom`, exposing them under the environment names above. Configure the Rails feature flag and gateway URL separately. No deployed account values are supplied by this change.

## Consent and send outcomes

Staff must explicitly select the permission already provided by the volunteer: one informational message, recurring messages with a confirmation, or recurring messages whose confirmation was already sent. Sprout does not infer consent from a phone number or contact preference. The selected consent type, recipient number, message body, staff user, and attempt time are retained on the communication record. US numbers are normalized to E.164; explicit international country codes are preserved.

| Outcome | Sprout status | Sent time |
|---|---|---|
| Sending disabled or input invalid | No send record; visible error | None |
| Provider returns `sent` | `sent`, with provider message ID | Recorded |
| Provider returns `queued` or `scheduled` | `queued`, with provider message ID | None |
| Provider returns `rejected` or `invalid` | `failed`, with provider ID and reason | None |
| Missing configuration or explicit gateway rejection | `failed`, with error | None |
| Timeout or unrecognized response | `pending`, with an uncertainty warning | None |

Only a confirmed `sent` result creates a sent timeline note. An accepted send is not proof of delivery. This change does not implement delivery webhooks; final delivery and later queue outcomes must be checked in Mailchimp. Uncertain attempts are not retried automatically, since a retry might duplicate a message. Failed requests preserve the compose draft.

## Grouped communication history

The volunteer profile shows existing email and SMS `Communication` records together, newest first, including status, message, timestamp, staff sender, and SMS provider ID where available. Timeline entries also display their communication status.

Mailchimp automatically logs transactional SMS alongside transactional email in Outbound Activity. Sprout retains the provider ID to cross-reference that activity. This does not import historical Mailchimp activity, marketing campaigns, or replies into Sprout, and does not implement the previously stubbed email delivery or audience-sync actions. Existing records that were marked delivered by the old local fallback are not retroactively verified or rewritten.

## Verification without live credentials

Run from WSL using Docker. These tests explicitly simulate provider responses at network boundaries and do not send real messages:

```bash
docker compose up -d db
docker compose run --rm --no-deps --entrypoint bash \
  -e RAILS_ENV=test \
  -e DATABASE_URL=postgres://sprout:sprout@db:5432/sprout_test web -lc \
  'bin/rails db:test:prepare && bin/rails tailwindcss:build && bundle exec rspec'

docker compose run --rm --no-deps --entrypoint bundle \
  -e RAILS_ENV=test \
  -e DATABASE_URL=postgres://sprout:sprout@db:5432/sprout_test web \
  exec cucumber features/07_sms_integration.feature
```

Coverage includes the controller-to-Lambda flow, the documented provider payload, sent/queued/rejected responses, phone and consent validation, missing configuration, timeouts, malformed responses, history rendering, and browser interaction. Actual account access and live delivery require separately supplied credentials and an approved sender; passing these tests does not verify them.
