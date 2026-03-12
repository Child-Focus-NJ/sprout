## 🌱 Sprout – Volunteer Management System

**Sprout** is a Ruby on Rails application that replaces spreadsheet-based workflows with a centralized system for managing the full volunteer lifecycle.

Sprout supports the journey from initial inquiry through information session attendance, application eligibility, and ongoing follow-up — giving staff a clear view of every volunteer’s status in one place.

---

## 👥 Team

Working under **Dr. Peter DePasquale**

- **Developers:** Isabelle Adams, Isabelle Larson, Wes Simpson, & Sufyan Waryah

---

## 🚀 Core Capabilities

- **Volunteer funnel tracking:** Inquiry → info session registered → attended → application eligible → applied → inactive, with a status history timeline.
- **Public inquiry form:** Tablet- and mobile-friendly public form that creates/links volunteers and starts them in the funnel.
- **Admin dashboard:** Staff-facing views to search, filter, and sort volunteers by name, status, and referral source.
- **Information sessions & attendance:** Create sessions, register volunteers, and use an electronic sign-in sheet to record attendance and automatically advance statuses.
- **Notes & communication history:** Inline notes and system-generated entries (status changes, attendance) for a unified volunteer timeline.

---

## 🛠️ Tech Stack

- **Language:** Ruby (3.4.5)
- **Framework:** Ruby on Rails 8.1.x
- **Database:** PostgreSQL
- **Cloud Services:** TBD
- **App Deployment:** TBD
- **Styling:** Tailwind CSS via `tailwindcss-rails`

Architecture, gem choices, and integration decisions are detailed in `docs/architecture-and-tech-stack.md` and `docs/feature-specifications.md`.

---

## ⚙️ Local Setup (Development)

### Option A: Docker (recommended)

One script starts everything — Rails, PostgreSQL, and LocalStack (AWS emulator) — in Docker containers. No local Ruby, Postgres, or AWS tools needed.

**Prerequisites:** [Docker Desktop](https://docs.docker.com/get-docker/)

```sh
bin/dev-docker
```

This will:
- Build the Rails dev image
- Start PostgreSQL and run migrations automatically
- Start LocalStack and provision all AWS resources (SQS queues, S3 bucket, Lambda functions, API Gateway)
- Start the Rails server on http://localhost:3000

To rebuild after Gemfile or Dockerfile changes:
```sh
bin/dev-docker --build
```

To reset everything (database, LocalStack state):
```sh
bin/dev-docker --reset
```

### Option B: Local Ruby (without AWS services)

1. **Install dependencies**
   ```sh
   bundle install
   ```

2. **Set up the database**
   ```sh
   bin/rails db:prepare
   ```

3. **Run the server**
   ```sh
   bin/rails server
   ```

Note: AWS integrations (Zoom, Mailchimp, Optima) won't work without LocalStack or real AWS credentials.

For more implementation details, see `docs/docker-setup.md`, `docs/mvp-plan.md`, and `docs/implementation-roadmap.md`.
