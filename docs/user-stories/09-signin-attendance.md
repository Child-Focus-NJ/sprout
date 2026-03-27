# Sign-in & Attendance

**As a** system administrator  
**I want to** use an electronic sign-in sheet for info sessions  
**So that** attendance is automatically tracked and triggers follow-up actions

**Acceptance criteria**

- Digital sign-in for sessions (`/information_sessions/:id/sign_in`).
- Pre-registered volunteers can be checked in; they are marked attended, date/time recorded, application-queued email sent, and funnel updated as implemented.
- Walk-ins not registered for that session are redirected to inquiry with session context; staff enter first name, last name, and email—new volunteers are created (with inquiry submission where applicable), existing emails reuse one volunteer record and complete attendance for the session.
- Volunteer status reflects attended session when first-session attendance is recorded (`Volunteer#status`).
- Timestamps support tracking when people attended (`checked_in_at`, `first_session_attended_at`).

**Out of scope (future work)**

- QR-based check-in, Zoom/virtual attendance automation, and a staff confirmation queue before application emails.
