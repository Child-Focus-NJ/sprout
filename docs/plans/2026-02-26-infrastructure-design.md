# Infrastructure Design

Date: 2026-02-26

## Overview

AWS infrastructure for Sprout, a Rails 8.1 volunteer management system. The design decouples external integrations (Zoom, Optima, MailChimp/Mandrill) into Lambda functions while keeping the Rails app focused on the web UI and data layer. All infrastructure is defined with AWS CDK (Python) and testable locally via LocalStack.

---

## Architecture

```
+----------------------------------------------------------------+
|                        AWS (Production)                         |
|                                                                 |
|  +---------------+     +---------------+     +---------------+  |
|  | Elastic       |     | RDS           |     | S3            |  |
|  | Beanstalk     |---->| PostgreSQL    |     | (reports,     |  |
|  | (Rails app)   |     |               |     |  exports,     |  |
|  +------+--------+     +------^--------+     |  assets)      |  |
|         |                     |              +---------------+  |
|         | HTTP                | read/write                      |
|         v                     |                                 |
|  +---------------+     +------+--------+                        |
|  | API Gateway   |---->| Lambda        |                        |
|  | (sync)        |     | Functions     |-->  Zoom API           |
|  |               |     | (Ruby 3.3)   |-->  Optima API          |
|  | 4 endpoints:  |     |              |-->  MailChimp/Mandrill  |
|  | zoom meeting  |     +--------------+                         |
|  | optima sync   |                                              |
|  | mailchimp/*   |                                              |
|  +------^--------+                                              |
|         |                                                       |
|    Rails calls synchronously                                    |
|                                                                 |
|  +---------------+     +---------------+                        |
|  | SQS Queues    |---->| Lambda        |                        |
|  | (async)       |     | (async)       |                        |
|  | 2 queues+DLQs |     +--------------+                         |
|  +---------------+                                              |
|                                                                 |
|  +---------------+                                              |
|  | EventBridge   |--(nightly cron)--> mailchimp_batch Lambda    |
|  +---------------+                                              |
+----------------------------------------------------------------+
```

---

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Cloud platform | AWS | Managed hosting + ecosystem integration |
| IaC tool | AWS CDK (Python) | Native AWS, team knows Python |
| Local development | LocalStack + Docker Compose | Test full infrastructure without AWS costs |
| Hosting | Elastic Beanstalk (Docker) | Managed ALB, auto-scaling, SSL, health checks |
| Database | RDS PostgreSQL | Existing relational schema, ActiveRecord compatibility |
| Object storage | S3 | Reports (PDF/CSV/XLSX), potentially email template assets |
| Async messaging | SQS (2 queues + DLQs) | Built-in retry, dead-letter queues, backpressure |
| Sync integrations | API Gateway + Lambda | Real-time request/response for user-facing operations |
| Scheduling | EventBridge (single nightly cron rule) | Native cron, triggers mailchimp_batch Lambda |
| Lambda runtime | Ruby 3.3 | Same language as Rails app, team familiarity |
| Repo structure | Monorepo | Single repo: Rails app + infra/ + lambdas/ |
| Email/SMS sending | All through mailchimp_realtime Lambda | MailChimp/Mandrill is the organization's comms platform; Rails orchestrates, Lambda sends |

---

## Lambda Functions (5 total)

### Sync (API Gateway)

| Function | Endpoint(s) | Purpose |
|---|---|---|
| `zoom_meeting` | `POST /zoom/meeting` | Create Zoom meeting via Zoom API, return meeting ID + join URL |
| `optima_sync` | `POST /optima/sync` | Push volunteer data to Optima API, return sync result |
| `mailchimp_realtime` | `POST /mailchimp/send-email` | Send transactional email via Mandrill API |
| | `POST /mailchimp/send-sms` | Send SMS via Mandrill Transactional SMS API |
| | `POST /mailchimp/member` | Add/update MailChimp audience member |
| | `POST /mailchimp/tags` | Update member tags by funnel stage |

### Async (SQS / EventBridge)

| Function | Trigger | Purpose |
|---|---|---|
| `zoom_attendance` | SQS queue | Fetch Zoom participants after session, match to volunteers in RDS |
| `mailchimp_batch` | SQS queue + EventBridge nightly schedule | Full audience reconciliation, campaign report pulls |

### Lambda Architecture

- Each function is a lightweight Ruby script (no Rails boot)
- Shared utilities (`shared/db.rb`, `shared/logger.rb`) bundled into each deployment
- Lambdas connect directly to RDS PostgreSQL via `DATABASE_URL`
- Gems: `httparty`, `pg`, `json`, `logger` (each function bundles only what it needs)

---

## Directory Structure

```
sprout/
+-- app/                    (Rails - Ruby)
+-- infra/                  (CDK - Python)
|   +-- app.py              CDK app entry point
|   +-- requirements.txt    CDK Python dependencies
|   +-- cdk.json            CDK config
|   +-- stacks/
|   |   +-- network_stack.py    VPC, subnets, security groups
|   |   +-- database_stack.py   RDS PostgreSQL
|   |   +-- storage_stack.py    S3 buckets
|   |   +-- queue_stack.py      SQS queues + DLQs
|   |   +-- lambda_stack.py     Lambda functions + IAM roles
|   |   +-- api_stack.py        API Gateway (sync endpoints)
|   |   +-- eb_stack.py         Elastic Beanstalk app + environment
|   +-- scripts/
|       +-- local_setup.py      Provisions LocalStack resources
+-- lambdas/                (Lambda functions - Ruby)
|   +-- shared/
|   |   +-- db.rb               PG connection helper
|   |   +-- logger.rb           Structured JSON logging
|   +-- zoom_meeting/
|   |   +-- handler.rb
|   |   +-- Gemfile
|   +-- zoom_attendance/
|   |   +-- handler.rb
|   |   +-- Gemfile
|   +-- optima_sync/
|   |   +-- handler.rb
|   |   +-- Gemfile
|   +-- mailchimp_realtime/
|   |   +-- handler.rb
|   |   +-- Gemfile
|   +-- mailchimp_batch/
|       +-- handler.rb
|       +-- Gemfile
+-- docker-compose.yml      (Rails + Postgres + LocalStack + setup)
+-- Dockerfile              (production)
+-- Dockerfile.dev          (development)
```

---

## Docker Compose (Local Development)

```
services:
  web:          Rails app (existing, adds AWS env vars)
  db:           PostgreSQL (existing, unchanged)
  localstack:   SQS, S3, Lambda, API Gateway, EventBridge
  setup:        Bootstrap container: provisions queues, buckets,
                deploys Lambdas to LocalStack, then exits
```

- `docker compose up` starts everything
- Rails uses `AWS_ENDPOINT_URL=http://localstack:4566` to route AWS SDK calls to LocalStack
- Postgres container serves as the local equivalent of RDS (identical behavior)
- Setup container runs after LocalStack is healthy, provisions all resources

---

## How Rails Communicates with Infrastructure

### Sync operations (API Gateway + Lambda)

Rails makes HTTP POST calls to API Gateway endpoints via HTTParty. In development, these hit LocalStack's API Gateway.

```
app/services/aws/lambda_client.rb
  - Reads API_GATEWAY_URL from environment
  - Makes POST requests to the appropriate endpoint
  - Returns parsed JSON response
  - Handles timeouts and errors
```

### Async operations (SQS)

Rails publishes JSON messages to SQS queues via aws-sdk-sqs. In development, the SDK endpoint is overridden to hit LocalStack.

```
app/services/aws/queue_publisher.rb
  - Reads SQS queue URLs from environment
  - Publishes JSON messages to the appropriate queue
  - Works transparently against LocalStack or real AWS
```

### New Rails gems

```ruby
gem "aws-sdk-sqs"   # Publish to SQS queues
gem "aws-sdk-s3"    # Store/retrieve reports and exports
```

### Environment variables

```
AWS_ENDPOINT_URL           # LocalStack URL in dev, omitted in prod
AWS_REGION                 # us-east-1
AWS_ACCESS_KEY_ID          # test (LocalStack) or real IAM in prod
AWS_SECRET_ACCESS_KEY      # test (LocalStack) or real IAM in prod
API_GATEWAY_URL            # Base URL for sync Lambda calls
SQS_ZOOM_ATTENDANCE_URL    # Queue URL
SQS_MAILCHIMP_BATCH_URL   # Queue URL
S3_REPORTS_BUCKET          # Bucket name
DATABASE_URL               # RDS connection string (same as today)
```

---

## CDK Stack Dependencies

```
network_stack
    |
    +----> database_stack (RDS in VPC)
    +----> storage_stack (S3)
    +----> queue_stack (SQS)
    |          |
    +----> lambda_stack (functions + IAM, needs VPC + queues)
    |          |
    +----> api_stack (API Gateway, needs Lambda ARNs)
    |
    +----> eb_stack (EB app, needs VPC + RDS + queue URLs + API URL)
```

---

## What Stays in Rails

- Google OAuth authentication (request/response in auth flow)
- Inbound webhooks from Mandrill and external systems (hit EB directly)
- Data import/export file processing
- Template rendering (Liquid) before passing content to Lambda
- Solid Queue for internal jobs (ProcessInquiryJob, etc.)
- All web UI, models, controllers, views

## What Moves to Lambda

- All MailChimp/Mandrill API calls (email, SMS, audience, tags)
- Zoom meeting creation
- Zoom attendance sync
- Optima volunteer data sync

---

## Inbound Webhooks (Hit Rails on EB Directly)

| Source | Endpoint | Purpose |
|---|---|---|
| Mandrill | `POST /webhooks/mandrill/email_status` | Email delivery tracking (bounces, opens, clicks) |
| Mandrill | `POST /webhooks/mandrill/sms_status` | SMS delivery status updates |
| External system | `POST /webhooks/external` | Application status events (HMAC verified) |

These require EB security group to allow inbound HTTPS from these services.
