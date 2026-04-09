# Mailchimp integration — onboarding

Short context for **why Mailchimp shows up in Sprout** and **what the code is doing**, so you can navigate the repo without guessing.

## Why Mailchimp?

Child Focus already uses **Mailchimp** for email and related communications. The product direction (see stakeholder notes and [`architecture-and-tech-stack.md`](architecture-and-tech-stack.md)) is to **keep transactional messaging in one place**: transactional email via Mailchimp Transactional (Mandrill), audience/tags via the Marketing API where needed, and **SMS via Mailchimp Transactional SMS** so staff are not juggling separate SMS vendors.

Credentials and production keys are provided by the team when they are ready to test or go live; local development does not require them.

## What Sprout does with it (big picture)

Sprout does **not** call Mailchimp’s HTTP APIs directly from every feature. Instead, the app talks to **AWS API Gateway**, which invokes a **Lambda** (`lambdas/mailchimp_realtime`) that exposes routes such as:

- `POST /mailchimp/send-email` — transactional email  
- `POST /mailchimp/send-sms` — transactional SMS  
- `POST /mailchimp/member`, `POST /mailchimp/tags` — audience / tagging (as implemented on the Lambda side)

On the Rails side, **`Aws::LambdaClient`** (`app/services/aws/lambda_client.rb`) is the thin client: it `POST`s JSON to those paths using the configured gateway base URL.

So: **Rails → API Gateway → Lambda → Mailchimp (Mandrill / Marketing as applicable).** That keeps secrets and provider details out of the web app and matches how other integrations (e.g. Zoom) are structured.

## SMS in this codebase (User Story 7)

Manual volunteer SMS from the UI goes through **`Sms::MailchimpOutbound`** (`app/services/sms/mailchimp_outbound.rb`), which calls **`Aws::LambdaClient#send_sms`** when the Mailchimp path is turned on. Outbound rows are stored as **`Communication`** records (`communication_type: :sms`) with status lifecycle (e.g. pending → delivered or failed) and timeline notes where appropriate (`app/models/communication.rb`).

**Default in dev/test:** if Mailchimp/Lambda is not enabled, the app **only records** the SMS in the database (no external HTTP). That keeps Docker and CI simple and matches how we run RSpec.

**To exercise the real Lambda/Mailchimp path:** set a truthy **`SPROUT_SMS_MAILCHIMP_ENABLED`** and ensure the gateway URL is available via **`API_GATEWAY_URL`** or **`API_GATEWAY_URL_FILE`** (see `docker-compose.yml` for the LocalStack file pattern).

## Where to read more

| Topic | Location |
|--------|-----------|
| Email, Marketing API, SMS product decisions | [`architecture-and-tech-stack.md`](architecture-and-tech-stack.md) (Mailchimp / Mandrill / SMS sections) |
| Lambda routes and handler | `lambdas/mailchimp_realtime/handler.rb` |
| Rails gateway client | `app/services/aws/lambda_client.rb` |
| Manual SMS flow | `Sms::MailchimpOutbound`, `VolunteersController#send_sms` |
| Mailchimp Transactional SMS (vendor docs) | [Mailchimp Transactional SMS](https://mailchimp.com/developer/transactional/docs/transactional-sms/) |

If something fails in production, check **Rails logs** for `[Sms::MailchimpOutbound]` and **Lambda/API Gateway** logs for the `mailchimp_realtime` function before assuming the bug is in the volunteer form or `Communication` model alone.
