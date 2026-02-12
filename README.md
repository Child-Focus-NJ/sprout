## 🌱 Sprout – Volunteer Management for Child Focus NJ

**Sprout** is a Ruby on Rails application that replaces spreadsheet-based workflows with a centralized system for managing the full volunteer lifecycle at Child Focus NJ.

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

Additional planned functionality (documented in `docs/`): automated email follow-ups, template management, Zoom attendance sync, SMS reminders, reporting, and external system integrations.

---

## 🛠️ Tech Stack

- **Language:** Ruby (see `.ruby-version`)
- **Framework:** Ruby on Rails 8.1.x
- **Database:** PostgreSQL
- **Background jobs:** Solid Queue
- **Caching & WebSockets:** Solid Cache, Solid Cable
- **Styling:** Tailwind CSS via `tailwindcss-rails`

Architecture, gem choices, and integration decisions are detailed in `docs/architecture-and-tech-stack.md` and `docs/feature-specifications.md`.

---

## ⚙️ Local Setup (Development)

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

For Docker-based setup and more implementation details, see `docs/docker-setup.md`, `docs/mvp-plan.md`, and `docs/implementation-roadmap.md`.

---

## 📄 Documentation

Design docs and specifications live in the `docs/` directory, including:

- `mvp-plan.md` – demo scope and build sequence
- `feature-specifications.md` – user-story–driven feature specs
- `user-stories/` – original user stories from stakeholders
- `architecture-and-tech-stack.md` – architecture, integrations, and cost estimates
