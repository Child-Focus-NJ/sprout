# User Story 7: SMS Integration

Staff can click a volunteer's name, choose **Send SMS**, and write a custom message or personalize an active SMS template. Drafts remain editable, show a character count, and require the volunteer's existing consent. The list and full SMS page offer the same flow and links to Mailchimp and Mandrill activity. Rails sends directly to Mailchimp Transactional. Configuration and provider errors preserve the draft and display an error.

See [Mailchimp integration](mailchimp-integration.md) for encrypted credentials, provider requirements, screenshot guidance, status semantics, and tests.

The profile groups stored email and SMS messages in its timeline. Provider acceptance is recorded as `sent` or `queued`, with the provider message ID; rejection is recorded as `failed`. Unknown outcomes stay `pending` with an explanation. Sprout no longer marks unsent local records as delivered. Final delivery webhooks and historical Mailchimp imports are not implemented.

## Key files

- `app/services/sms/mailchimp_outbound.rb`: validation, consent, phone normalization, persistence, and send outcomes.
- `app/services/mailchimp/transactional_client.rb`: the only Mandrill send path, including consent values and transport errors.
- `app/models/communication.rb`: communication status and sent timeline notes.
- `app/views/volunteers/_message_dialog.html.erb`, `sms.html.erb` and `show.html.erb`: composition and grouped history.
- `app/javascript/sms_templates.js`: load personalized templates without overwriting newer drafts.

## Related work

- [Issue #210: Fix SMS + Integrate Mailchimp](https://github.com/Child-Focus-NJ/sprout/issues/210)
- [PR #50: Failing BDD for User Stories 5–8](https://github.com/Child-Focus-NJ/sprout/pull/50)
- [PR #82: User Story 7 Green](https://github.com/Child-Focus-NJ/sprout/pull/82)
- [PR #104: User Story 7 Refactor](https://github.com/Child-Focus-NJ/sprout/pull/104)
