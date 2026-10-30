source "https://rubygems.org"

# ---------------------------------------------------------------------------
# Framework
# ---------------------------------------------------------------------------
# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.2", ">= 8.1.3.1"

gem "pg", "~> 1.7"                          # PostgreSQL
gem "puma", ">= 5.0"                        # Web server
gem "bootsnap", require: false              # Boot-time caching (required in config/boot.rb)
gem "tzinfo-data", platforms: %i[ windows jruby ] # Windows has no zoneinfo files

# Database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# ---------------------------------------------------------------------------
# Frontend
# ---------------------------------------------------------------------------
gem "propshaft"                             # Asset pipeline
gem "tailwindcss-rails", "~> 4.0"
gem "importmap-rails"                       # JavaScript with ESM import maps
gem "turbo-rails"                           # Hotwire page accelerator
gem "stimulus-rails"                        # Hotwire JavaScript framework

# Dashboard charts (Chart.js, loaded through importmap) [https://chartkick.com]
gem "chartkick"
# Group counts by day/week/month in the app's time zone, for chart series
gem "groupdate"

# ---------------------------------------------------------------------------
# Authentication
# ---------------------------------------------------------------------------
gem "omniauth", ">= 2.0.0"                  # Single Sign-On
gem "omniauth-google-oauth2"

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
gem "dotenv-rails"                          # Load .env files

# ---------------------------------------------------------------------------
# Integrations & file handling
# ---------------------------------------------------------------------------
gem "httparty"                              # HTTP client for API Gateway calls and external APIs

# AWS SDK (SQS for async Lambda triggers, S3 for report storage)
gem "aws-sdk-s3", "~> 1.235"
gem "aws-sdk-sqs", "~> 1.122"

gem "caxlsx"                                # Excel generation for data exports (admin full-data export, reporting)
gem "prawn"                                 # PDF generation for report exports
gem "roo"                                   # Spreadsheet import (volunteer import)
gem "image_processing", "~> 1.2"            # Active Storage variants

# ---------------------------------------------------------------------------
# Deployment
# ---------------------------------------------------------------------------
gem "kamal", require: false                 # Deploy as a Docker container
gem "thruster", require: false              # HTTP caching/compression and X-Sendfile for Puma

# ---------------------------------------------------------------------------
# Development & test
# ---------------------------------------------------------------------------
group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "factory_bot_rails"

  # Code quality & security
  gem "brakeman", "~> 8.1.0", require: false  # Static security analysis
  gem "bundler-audit", require: false         # Audits gems for known vulnerabilities (config/bundler-audit.yml)
  gem "rubocop-rails-omakase", require: false # Omakase Ruby styling
end

group :development do
  gem "web-console"
end

group :test do
  # RSpec
  gem "rspec-rails", "~> 8.0"
  gem "shoulda-matchers", "~> 6.0"
  gem "database_cleaner-active_record"
  gem "simplecov", require: false
  gem "warden"                              # Warden::Test::Helpers (login_as) in RSpec and Cucumber
  gem "webmock"                             # Stubs the raw Net::HTTP calls ExternalVmsSync makes to the external VMS

  # Build and inspect exported files in specs and features
  gem "pdf-reader"
  gem "rubyXL"

  # Cucumber / browser testing
  # require: false so these are not loaded by Bundler.require under RSpec;
  # Cucumber loads them from features/support/env.rb
  gem "capybara", require: false
  gem "cucumber-rails", require: false
  gem "selenium-webdriver", require: false
end