# 325 — How information session registration works today

Investigation for [issue 325](https://github.com/Child-Focus-NJ/sprout/issues/325). Sprout can store a registration, but nothing in the app currently pulls Squarespace or Google Sheets into that table.

## How someone gets onto a session today

`SessionRegistration` is the roster. Its status is `registered`, `attended`, `no_show`, `cancelled`, or `rescheduled`, and a volunteer can have only one row per session.

Production code writes that table in one place: `Volunteer#finalize_check_in_for_session!`. It creates the row if needed and immediately marks it `attended`. Two screens call it:

- **Session sign-in** (`InformationSessionsController#check_in`). Staff enter an email. An existing `registered` row is checked in. If the person or the row is missing, staff are sent to the inquiry form with that session id.
- **Walk-in inquiry** (`InquiryFormController#create` when `information_session_id` is present). A new volunteer is created at funnel stage Inquiry, an `InquiryFormSubmission` is stored with source `walk_in_check_in` and `preferred_session` set, and the same check-in method marks them attended.

The public inquiry form does not register anyone for a session. It creates a volunteer and an `InquiryFormSubmission` with source `public_inquiry_form`, leaves `preferred_session` blank, and never creates a `SessionRegistration`. The form has no session picker.

The session edit page lists volunteers already tied to the session and can delete the registration. It cannot add one.

Two other imports create volunteers only, not registrations:

- **Excel upload** (`VolunteerImportService`) reads `email`, `first_name`, and `last_name`.
- **eVinto sync** (`ExternalVmsSync`) pulls active inquiries from the county VMS and stores a volunteer plus an inquiry submission. It does not read or write information sessions.

Seeds and tests insert `SessionRegistration` rows directly. That is the only way a row stays `registered` instead of jumping to `attended`.

## Squarespace

There is no Squarespace client, webhook, form mapping, or configuration in this repository. A Squarespace signup does not reach Sprout unless somebody copies it in by hand.

## Google Sheets

There is no Google Sheets API client, service account, or scheduled sheet sync. The docs describe Sprout as the replacement for the sheet workflow. The spreadsheet code that does exist is a one-time Excel import of volunteer names and an Excel export of Sprout data. Neither one reads or writes session registrations.

## What has to change to keep registrations in sync

Sprout should stay the roster. `SessionRegistration` already has the statuses staff need for a headcount, a current registrant list, and a past-session outcome. A sync should write those rows, not a second list.

1. **Add a registration write that does not check the person in.** The only production write marks the person attended. An advance signup needs a `registered` row (and `registered_at`) for a matched volunteer and session. Cancelling sets that row to `cancelled`. Rescheduling sets the old row to `rescheduled` and creates a `registered` row on the new session. Staff outcome notes in issue 304 should call that same write so the roster, the count, and the past-session tags stay on one record.

2. **Do not treat `InquiryFormSubmission.preferred_session` as the roster.** Walk-in submissions set it only because check-in already happened. The public form leaves it empty. Counting those rows would mix inquiries with people who actually hold a seat.

3. **Squarespace needs an inbound path and a stable session id.** A form webhook (or a polled Forms API) can post name, email, phone, and the chosen session into the registration write above. Match the session by Sprout id, not by a date string. The unique index on volunteer plus session makes a repeated delivery update the same row instead of inserting another. Squarespace forms do not emit cancellations, so a cancel or reschedule still has to be entered in Sprout, or the form has to grow a second submission that the endpoint understands. The session choices on the Squarespace form are a copy of Sprout's upcoming sessions and will drift until those choices are generated from Sprout or updated when a session is created, edited, or cancelled.

4. **Google Sheets needs the same inbound path, plus a conflict rule.** An Apps Script `onFormSubmit` / `onEdit` posting to Sprout, or a scheduled pull with the Sheets API, can feed the same registration write. Match on email plus session id. If a staff member changed the Sprout row after the sheet row's timestamp, keep Sprout. The current Excel import cannot do this: it has no session column and it never updates an existing registration.

5. **Unknown sessions should stay unregistered.** If a sheet or form names a session Sprout cannot find, store the payload on the inquiry submission and leave the roster unchanged rather than guessing a nearby date.
