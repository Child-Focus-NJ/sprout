# User Story 7: SMS Integration

Staff can open **Send SMS** from the volunteer list or profile, compose up to 320 characters, and select the SMS consent the volunteer has provided. Sprout sends through the API Gateway and Mailchimp Transactional Lambda when configured. Configuration and provider errors preserve the draft and display an error.

See [Mailchimp integration](mailchimp-integration.md) for WSL/Docker setup, the `MAILCHIMP_API_KEY` placeholder, provider requirements, status semantics, and tests.

The profile groups stored email and SMS messages in **Communication history**. Provider acceptance is recorded as `sent` or `queued`, with the provider message ID; rejection is recorded as `failed`. Unknown outcomes stay `pending` with an explanation. Sprout no longer marks unsent local records as delivered. Final delivery webhooks and historical Mailchimp imports are not implemented.

## Key files

- `app/services/sms/mailchimp_outbound.rb`: validation, consent, phone normalization, persistence, and send outcomes.
- `app/services/aws/lambda_client.rb`: gateway request and transport errors.
- `lambdas/mailchimp_realtime/handler.rb` and `sms_client.rb`: request validation and documented Mailchimp API call.
- `app/models/communication.rb`: communication status and sent timeline notes.
- `app/views/volunteers/sms.html.erb` and `show.html.erb`: composition and grouped history.
- `localstack/init/setup.sh`: deploys the real SMS Lambda in Docker.

## Related work

- [Issue #210: Fix SMS + Integrate Mailchimp](https://github.com/Child-Focus-NJ/sprout/issues/210)
- [PR #50: Failing BDD for User Stories 5–8](https://github.com/Child-Focus-NJ/sprout/pull/50)
- [PR #82: User Story 7 Green](https://github.com/Child-Focus-NJ/sprout/pull/82)
- [PR #104: User Story 7 Refactor](https://github.com/Child-Focus-NJ/sprout/pull/104)
