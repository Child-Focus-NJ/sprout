# Mailchimp Integration

Sprout uses Mailchimp for:
- Transactional email (Mandrill / Mailchimp Transactional)
- SMS messaging
- Optional tagging / audience updates

We solve this issue by centralizing communication in one provider

---

## High-Level Architecture

Sprout does not call Mailchimp directly, but rather:

Rails → API Gateway → AWS Lambda → Mailchimp

- Rails sends requests via `Aws::LambdaClient`
- API Gateway forwards to `lambdas/mailchimp_realtime`
- Lambda handles all Mailchimp API interactions

---

## SMS Flow (User Story 7)

SMS is handled by `Sms::MailchimpOutbound`.

1. Staff sends SMS from volunteer profile
2. Rails calls `Sms::MailchimpOutbound.deliver!`
3. If Mailchimp is enabled:
   - Request goes to `Aws::LambdaClient#send_sms`
   - Stored in `Communication` with delivery status
4. If disabled:
   - SMS is only stored locally (no external request)

---

## Environments

| Environment | Behavior |
|------------|----------|
| Dev / Test | Stores SMS locally only |
| Production | Sends via Lambda → Mailchimp |

Enabled by:
- `SPROUT_SMS_MAILCHIMP_ENABLED`
- `API_GATEWAY_URL` or `API_GATEWAY_URL_FILE`

---

## Key Files

| Area | File |
|------|------|
| SMS service | `app/services/sms/mailchimp_outbound.rb` |
| Lambda client | `app/services/aws/lambda_client.rb` |
| Controller | `app/controllers/volunteers_controller.rb` |
| Data model | `app/models/communication.rb` |
| Lambda handler | `lambdas/mailchimp_realtime/handler.rb` |

---

## Debugging

If something breaks, check:
1. Rails logs (`Sms::MailchimpOutbound`)
2. `Communication` records in DB
3. Lambda logs (`mailchimp_realtime`)
4. API Gateway response

---

## External ref

- Mailchimp Transactional SMS  
  https://mailchimp.com/developer/transactional/docs/transactional-sms/
