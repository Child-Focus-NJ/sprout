# Security Policy

Sprout is a volunteer management system built for Child Focus NJ. It handles
personal information about volunteers, so we take security reports seriously
and appreciate the time researchers put into helping us keep it safe.

## Supported Versions

Sprout does not currently publish versioned releases or tags. Security fixes are
applied to the `main` branch, and only the latest code on `main` is supported.

<!-- TODO: Once a release cycle exists, replace the paragraph above with a
     version support table, for example:

| Version | Supported          |
| ------- | ------------------ |
| 1.x     | :white_check_mark: |
| < 1.0   | :x:                |
-->

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues,
pull requests, or discussions.**

Report privately using GitHub's private vulnerability reporting: go to the
[Security tab](https://github.com/Child-Focus-NJ/sprout/security) of this
repository, click **Report a vulnerability**, and fill out the form. Your report
is visible only to the maintainers until we choose to publish an advisory.

Please include as much of the following as you can:

- A description of the vulnerability and its potential impact
- Steps to reproduce, or a proof of concept
- The affected endpoint or file path
- Any suggested fix or mitigation
- Your name or handle if you would like to be credited

**Please do not include real volunteer data** in your report. If you come across
personal information while testing, stop, do not copy or retain it, and let us
know so we can respond.

## What to Expect

Sprout is maintained by a small team, so these are good-faith targets rather
than guarantees.

| Step                                      | Target timeline          |
| ----------------------------------------- | ------------------------ |
| Acknowledgment of your report             | Within 10 business days  |
| Initial assessment and severity rating    | Within 20 business days  |
| Fix or mitigation for confirmed issues    | Based on severity (see below) |
| Notification when the issue is resolved   | Upon deployment of a fix |

Target fix windows after confirmation: critical within 30 days, high within 60
days, and medium and low as scheduled in normal development.

We will keep you informed of progress and let you know if we need more
information.

## Disclosure Policy

We ask that you give us a reasonable opportunity to fix an issue before any
public disclosure. We follow coordinated disclosure:

- We will work with you to understand and resolve the issue.
- We ask that you wait 90 days from your report, or until a fix is
  deployed (whichever is first), before disclosing publicly.
- Once resolved, we may publish a GitHub Security Advisory and will credit you
  unless you prefer to remain anonymous.

## Scope

### In scope

- The Sprout Rails application code in this repository (admin dashboard, public
  inquiry form, information session and sign-in features)
- Other code and configuration in this repository, including `infra/`,
  `lambdas/`, `.github/`, and deployment configuration
- Authentication, authorization, and session handling
- Handling of volunteer personal data

**There is no live production deployment available for testing.** Please do not
probe any Child Focus NJ or AWS-hosted systems. Test against your own local
instance of the code instead (the README describes a Docker-based setup), using
synthetic data only.

### Out of scope

- Any live Child Focus NJ or AWS-hosted infrastructure
- Denial-of-service or volumetric attacks, and automated high-volume scanning
- Social engineering or phishing of Child Focus NJ staff or volunteers
- Physical attacks
- Vulnerabilities in third-party services we integrate with (AWS, Zoom,
  Mailchimp, the volunteer management system integration). Please report these
  to the vendor directly.
- Findings that require physical access to an already-compromised device
- Missing security headers or best-practice recommendations with no
  demonstrable impact
- Vulnerabilities in outdated browsers or unsupported platforms

<!-- TODO: Safe harbor section removed for now. Revisit with Child Focus NJ
     (and counsel, if appropriate) before reinstating. This language makes a
     legal commitment on the organization's behalf.

## Safe Harbor

If you act in good faith and follow this policy, we will not pursue or support
legal action against you for your research. Good faith means you:

- Make every effort to avoid privacy violations, data destruction, and
  disruption to the service
- Only interact with accounts you own or have explicit permission to test
- Do not access, modify, or retain more data than needed to demonstrate the issue
- Report the issue promptly and do not exploit it beyond a proof of concept
-->

<!-- TODO: Security Practices section commented out until each statement has
     been verified. Review every line, delete what is not true, and add what is
     missing. Items marked (verify) are assumptions from the repo layout.

## Security Practices

- **Data protection:** Volunteer data is stored in PostgreSQL. Traffic is
  served over HTTPS. [TODO: encryption at rest / sensitive field encryption]
- **Secrets management:** Credentials and API keys are never committed to the
  repository. They are supplied through environment variables or a secrets
  manager. [TODO: Rails credentials, AWS Secrets Manager, SSM Parameter Store?]
- **Authentication and access:** Staff access to the admin dashboard requires
  authentication. [TODO: describe auth method, MFA, roles/permissions]
- **Dependency management:** Dependencies are pinned in Gemfile.lock and
  monitored for known vulnerabilities. (verify: Dependabot / bundler-audit)
- **Static analysis:** The project uses RuboCop, and [TODO: Brakeman / CodeQL]
  for security scanning in CI. (verify)
- **Code review:** Changes to main go through pull request review before
  merging. (verify: branch protection enabled)
- **Public form protections:** The public inquiry form is protected against
  abuse and common web vulnerabilities (CSRF, XSS, SQL injection) using Rails'
  built-in protections. [TODO: rate limiting / bot protection]
-->

## Data Handling

Sprout stores personal information about prospective and active volunteers,
including names, addresses, phone numbers, and email addresses, along with
information session attendance and staff notes.

Contributors must never commit real volunteer data to this repository, including
in test fixtures, seed files, screenshots, or logs. Use synthetic data only.

## Guidance for Contributors

- Never commit secrets, API keys, credentials, or `.env` files. If you commit
  one by accident, tell a maintainer immediately so it can be rotated; deleting
  it in a later commit is not enough.
- Use synthetic data for development and testing.
- Run the test suite and linters before opening a pull request.
- Keep dependencies up to date, and flag any with known vulnerabilities.
- Report suspected vulnerabilities privately, following the process above.

## Acknowledgments

We are grateful to the researchers who help keep Sprout and its users safe.
Reporters who follow this policy will be credited here, with their permission.

_No reports have been received yet._

## Contact

Please submit vulnerability reports through GitHub private vulnerability
reporting (see above) rather than by email.

Maintainers:

- sprout@passaiccountycasa.org
- peter.depasquale@nyu.edu

Organization: [Child Focus NJ](https://github.com/Child-Focus-NJ)
