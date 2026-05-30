# Changelog

All notable changes to this project will be documented in this file.

## [unreleased]

### ⛰️  Features

- *(uncategorized)* Add web UI login/signup tabs, dashboard with medication adherence

### 🐛 Bug Fixes

- *(uncategorized)* Fixed the main layout problems:

  - Empty desktop tables no longer render wide hidden columns that cause a useless scrollbar.
  - Empty states now render as normal centered text blocks.
  - Main container widened from max-w-6xl to max-w-7xl.
  - Right rail narrowed from 380px to 340px.
  - Header stacks better on phone.
  - Mobile uses card-style stat sections; desktop uses tables.
  - Removed the PWA portrait orientation lock so the installed app can rotate.

### ⚙️ Miscellaneous Tasks

- *(files)* Update files
- *(files)* Update files
- *(uncategorized)* Test post-commit changelog hook
- *(uncategorized)* Add git-cliff changelog config

### 📦 Other

- *(uncategorized)* Update docs
- *(uncategorized)* Fixed. Clicking an existing placeholder now loads its admin fields but keeps the medication name casing you typed in the form.
- *(uncategorized)* Ignore local Cloudflare config
- *(uncategorized)* What changed:

  - Added PATCH /api/v1/medications/:id so medication admin details can be edited.
  - Added POST /api/v1/medications/:id/merge so one medication can absorb another medication’s dose history, then deactivate the duplicate.
  - Updated the Add Medication UI:
      - Typing a name now detects existing/near-match medications.
      - Exact matches switch the save action to Update medication.
      - Match cards can load existing details into the form.
      - If a target is selected and another match exists, a Merge button appears.
      - You can still choose Create a separate medication instead.
  - Placeholder imported meds no longer display 1 unit per unit in the med table.
- *(uncategorized)* Implemented a journal importer/backfill path.

  What it does:

  - Reads nested journal files under /home/jwl/projects/notes/journal/**/*.md.
  - Parses YAML frontmatter.
  - Imports typed records for BP, sleep, weight, steps, and medication doses.
  - Parses ## Meds dose lines like med:: [[lisinopril]] | qty:: 2.
  - Imports frontmatter sleep meds from med, med_type, qty.
  - Uses deterministic client_uuids so you can re-run it without duplicating events.
  - Supports aliases for older metric names like am_*/pm_* as well as wake_*/sleep_*.
  - Allows sleep minutes to import even when older notes lack bedtime/wake_time.
- *(uncategorized)* Moved sleep parity forward.

  - Added timing_context to medication dose payloads: wake, sleep, other.
  - Added med_type to medications so med_type: Cannabis becomes canonical medication metadata, not a sleep field.
  - Updated the sleep dashboard report to include Datacore-style:
      - By Medication
      - By Medication Type
      - Sleep Efficiency
      - Sleep Efficiency Summary
  - Implemented the cross-day rule: a sleep-timed medication dose on one day links to the next day’s sleep/steps/wake BP, while also considering same-night sleep BP.
  - Added a parity-style test covering:
      - sleep_minutes separate from time in bed
      - sleep_meds -> next day sleep
      - med -> by medication
      - med_type -> by medication type
      - avg sleep, avg qty, avg BP, avg steps, nights, BP reads
  - Added UI fields for medication type and dose timing context.
- *(uncategorized)* Implemented the first Rails-backed dashboard pass.

  What changed:

  - Added canonical legacy metric mapping in docs/design/legacy_metric_mapping.md and Reports::LegacyMetricMap.
  - Added sleep_minutes to sleep payloads so tracker sleep is separate from time-in-bed.
  - Updated sleep projections to derive time_in_bed_minutes, awake_minutes, and sleep_efficiency_percent.
  - Added report API endpoints:
      - GET /api/v1/reports
      - GET /api/v1/reports/:id
  - Added first-pass Rails report services for:
      - weekly_summary
      - daily_metrics_dashboard
      - sleep_dashboard
      - meds_dashboard
      - bp_readings
      - trends_dashboard
      - correlations_dashboard
      - dietitian_report
  - Added a generic web report viewer at web/app/reports/page.tsx, linked from the dashboard.
  - Updated the sleep entry UI to accept tracker sleep minutes.
- *(uncategorized)* Implemented it in web/app/dashboard/page.tsx.

  What changed:

  - Replaced separate Add medication / Add data actions with one Add record button.
  - Add record now supports:
      - New medication
      - Medication dose
      - Blood pressure / heart rate
      - Weight
      - Sleep
      - Steps
  - Added Edit records.
      - Opens recent records.
      - Selecting one reuses the record modal in edit mode.
      - Saves corrections through the existing Rails /api/v1/health_events/:id/amend endpoint.
- *(uncategorized)* Changes:

  - Removed "orientation": "portrait-primary" from web/public/manifest.webmanifest:1, so the installed PWA can rotate with the phone.
  - Made the dashboard mobile-friendly:
      - Header stacks cleanly on narrow screens.
      - Stat tables render as mobile card lists on phone widths.
      - Full horizontal tables remain for tablet/desktop.
  - Kept the metric-aware Add data modal:
      - Meds: medication, dose, type
      - BP/HR: wake/sleep, sys, dia, HR
      - Weight: lb
      - Sleep: bedtime/wake time
      - Steps: step count
- *(uncategorized)* The dashboard now keeps the stat tables as the main view and uses a smart Add data modal. The modal has a metric selector and surfaces only the fields for that metric:

  - Medication dose: medication, dose, dose type
  - Blood pressure / HR: wake/sleep, systolic, diastolic, heart rate
  - Weight: weight in lb, stored canonically as kg with original lb preserved
  - Sleep: bedtime and wake time
  - Steps: step count, stored as an activity event
- *(uncategorized)* Reshaped the dashboard
- *(uncategorized)* Add medication and dose logging workflow
- *(uncategorized)* Prepare static assets for standalone deploy
- *(uncategorized)* Add PWA support and TOTP setup flow
- *(uncategorized)* Fix zxcvbn feedback hash access in password validator
- *(uncategorized)* Simplify production DB config to single database
- *(uncategorized)* Fix production DB connection to use TCP
- *(uncategorized)* Wire login form to API, fix devices controller username lookup
- *(uncategorized)* Add username auth, password complexity validation
- *(uncategorized)* Use Atkinson Hyperlegible Next font
- *(uncategorized)* Add dark mode landing page
- *(uncategorized)* Allow api.bodyledger.org host in development
- *(uncategorized)* Allow api.bodyledger.org host in production
- *(uncategorized)* Add TOTP auth, registration, CORS, consumed_timestep migration
- *(uncategorized)*   Initial scaffold: schema, models, projectors, and REST API

  - Append-only event ledger schema (users, devices, health_events,
    7 payload tables, daily_summaries, sync_cursors, sync_logs, medications)
  - ImmutableRecord concern; amendment chain on HealthEvent
  - Projectors for all 7 metric types
  - Full REST API (auth, devices, health_events + amend, medications,
    summaries, sync) with device token auth
- *(uncategorized)* Update README
- *(uncategorized)* Add gitignore
- *(uncategorized)* Intial commit

<!-- generated by git-cliff -->
