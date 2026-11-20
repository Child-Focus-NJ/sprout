# 325 — How information session registration works today

Investigation for [issue 325](https://github.com/Child-Focus-NJ/sprout/issues/325). Sprout can store a registration, but nothing in the app currently pulls Squarespace or Google Sheets into that table.

## How someone gets onto a session today

`SessionRegistration` is the roster. Status is `registered`, `attended`, `no_show`, `cancelled`, or `rescheduled`. A volunteer has at most one row per session.

### What production writes today

| Path | What it does to `SessionRegistration` |
| --- | --- |
| **Session check-in** (`Volunteer#finalize_check_in_for_session!` via `InformationSessionsController#check_in`) | Finds or creates the row and marks it `attended`. Missing person/row → staff go to the walk-in inquiry form with that session id. |
| **Walk-in inquiry** (`InquiryFormController#create` with `information_session_id`) | Creates volunteer + `InquiryFormSubmission` (`walk_in_check_in`, `preferred_session` set), then the same check-in method marks them `attended`. |
| **Session outcome notes** (`Volunteer#add_note_with_outcome!`) | Updates an existing row: attended / no-show / cancelled, or **reschedule** (old → `rescheduled`, new session → `registered` unless already attended). Shipped with issue 304. |
| **Remove attendee** (`InformationSessionsController#remove_attendee`) | Deletes the registration row from the session edit page. Edit can remove; it cannot add. |

There is **no** advance-signup write that creates a fresh `registered` row for a new external signup. The production paths that leave a row as `registered` are reschedule (new session) and direct inserts in seeds/tests.

### What does not register anyone

- **Public inquiry form** — creates a volunteer and an `InquiryFormSubmission` (`public_inquiry_form`), leaves `preferred_session` blank, never creates a `SessionRegistration`. No session picker.
- **Excel upload** (`VolunteerImportService`) — creates volunteers from `email` / `first_name` / `last_name` only. No session column, no registrations.

(The former eVinto / `ExternalVmsSync` path is gone from main as of #451; it also never wrote session registrations.)

## Squarespace

There is no Squarespace client, webhook, form mapping, or configuration in this repository. A Squarespace signup does not reach Sprout unless somebody copies it in by hand.

## Google Sheets

There is no Google Sheets API client, service account, or scheduled sheet sync. The docs describe Sprout as the replacement for the sheet workflow. The spreadsheet code that does exist is a one-time Excel import of volunteer names and an Excel export of Sprout data. Neither one reads or writes session registrations.

## What has to change to keep registrations in sync

Sprout should stay the roster. `SessionRegistration` already has the statuses staff need for a headcount, a current registrant list, and a past-session outcome. A sync should write those rows, not a second list.

1. **Add a registration write that does not check the person in.** Check-in marks attended. Advance signup needs a `registered` row (and `registered_at`) for a matched volunteer and session. Cancelling sets that row to `cancelled`. Rescheduling already exists via outcome notes (old → `rescheduled`, new → `registered`); an inbound sync should reuse the same status rules so the roster, the count, and past-session tags stay on one record.

2. **Do not treat `InquiryFormSubmission.preferred_session` as the roster.** Walk-in submissions set it only because check-in already happened. The public form leaves it empty. Counting those rows would mix inquiries with people who actually hold a seat.

3. **Squarespace needs an inbound path and a stable session id.** A form webhook (or a polled Forms API) can post name, email, phone, and the chosen session into the registration write above. Match the session by Sprout id, not by a date string. The unique index on volunteer plus session makes a repeated delivery update the same row instead of inserting another. Squarespace forms do not emit cancellations, so a cancel or reschedule still has to be entered in Sprout, or the form has to grow a second submission that the endpoint understands. The session choices on the Squarespace form are a copy of Sprout's upcoming sessions and will drift until those choices are generated from Sprout or updated when a session is created, edited, or cancelled.

4. **Google Sheets needs the same inbound path, plus a conflict rule.** An Apps Script `onFormSubmit` / `onEdit` posting to Sprout, or a scheduled pull with the Sheets API, can feed the same registration write. Match on email plus session id. If a staff member changed the Sprout row after the sheet row's timestamp, keep Sprout. The current Excel import cannot do this: it has no session column and it never updates an existing registration.

5. **Unknown sessions should stay unregistered.** If a sheet or form names a session Sprout cannot find, store the payload on the inquiry submission and leave the roster unchanged rather than guessing a nearby date.
