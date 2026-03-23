# Body Ledger

A personal health tracking system built on an append-only event ledger — the same principle as double-entry bookkeeping applied to health data. No deletes, no overwrites, full audit trail, offline-first across all clients.

---

## Architecture

### Design Philosophy

- **Immutable ledger** — health events are never modified or deleted. Corrections are amendment events that reference the original (`supersedes_id`). The current state of any metric is always computable from the full event log.
- **Thin clients** — clients record raw events and render results. All business logic (summaries, adherence, correlations, trends) lives in Rails. One correct implementation, applied everywhere.
- **Offline-first** — every client buffers to local SQLite and syncs when connected. The append-only model means sync is almost always just appending; true conflicts are rare.
- **Full data ownership** — self-hosted. No third-party cloud, no lock-in.

### The Ledger Analogy

| Accounting | Body Ledger |
|------------|-------------|
| Journal entry | Health event (BP reading, dose taken) |
| Ledger | Append-only event log |
| Adjusting entry | Amendment event referencing original |
| Trial balance | Projected daily summary |
| Reconciliation | Physical pill count vs calculated inventory |

---

## Stack

| Layer | Technology |
|-------|------------|
| Backend / sync hub | Rails 8.1 + PostgreSQL |
| Web client | To be decided |
| Android client | Kotlin (native), Room, WorkManager, Health Connect |
| Desktop client | Rust + iced (Wayland-native, KDE) |
| Android local DB | Room (SQLite) |
| Desktop local DB | rusqlite + sqlx or diesel (SQLite) |
| Auth | Devise + devise-two-factor (TOTP MFA) |

**Supported platforms:** Android, Web, Desktop (Linux/Wayland) — no iOS or macOS.

---

## Metric Types

| Metric | Key fields |
|--------|------------|
| Blood pressure | systolic, diastolic, pulse, reading_context (wake/sleep — never averaged together) |
| Weight | value_kg, original_unit, original_value |
| Sleep | sleep_start, sleep_end, duration (generated); attributed to wake date |
| Activity | activity_type, duration_minutes, distance_km, steps, heart_rate_avg, calories_burned |
| Nutrition | meal_type, 7 macro columns, micronutrients (JSONB) |
| Symptom | symptom_code, severity (1–10), body_location |
| Medication dose | medication_id, dose_mg, dose_type (scheduled/prn/missed/reconciliation) |

---

## Current Status

### Backend — Rails API

**Complete:**
- Full PostgreSQL schema with all tables and constraints
- Immutable ActiveRecord models with amendment chain support
- Projectors for all 7 metric types that materialize `daily_summaries`
- Complete REST API:

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/auth/login` | Validate credentials, return user info |
| POST | `/api/v1/devices` | Register device, return token (shown once) |
| PATCH | `/api/v1/devices/:id` | Update last_seen_at / deactivate |
| GET | `/api/v1/health_events` | List events (filter: metric_type, date range, status) |
| POST | `/api/v1/health_events` | Create event + payload in one request; idempotent via client_uuid |
| GET | `/api/v1/health_events/:id` | Single event with payload |
| POST | `/api/v1/health_events/:id/amend` | Amend event; original marked superseded atomically |
| GET | `/api/v1/medications` | List user medications |
| POST | `/api/v1/medications` | Create medication |
| GET | `/api/v1/summaries` | Daily summaries (triggers projectors on request) |
| POST | `/api/v1/sync` | Pull events from other devices since last_synced_at |

- Device token auth (`Authorization: Bearer <token>`) on every request except registration
- SHA-256 token digest stored in DB — O(1) indexed lookup, 256-bit entropy

**Not yet done:**
- Devise + devise-two-factor not added to Gemfile; User model is a placeholder
- No user registration endpoint
- No TOTP verification step in login flow
- CORS not configured (needed for web client)
- Confirmation workflow: events default to `pending`; promotion rule not yet decided
- PostgreSQL not installed; migrations not run; `bundle install` not run
- No tests

### Web Client — Not started

### Android Client — Not started

### Desktop Client (Rust + iced) — Not started

---

## Next Steps

### Immediate (get the API running)
1. Add Devise + devise-two-factor to Gemfile; wire up User model
2. Add user registration endpoint
3. Add TOTP step to login flow
4. Configure CORS (`rack-cors`)
5. Install PostgreSQL, create database, run migrations
6. Decide confirmation rule (auto-confirm on sync? manual? Health Connect data = auto-confirmed?)

### Web Client (MVP)
- Auth UI (login + TOTP)
- Metric entry forms (one per metric type)
- History view (filterable event list)
- Daily summary view
- Settings (medications, device management)

### Android Client
- Room schema mirroring the event model
- Health Connect integration (import steps, sleep, HR automatically)
- WorkManager background sync job
- Same metric entry forms and views as web
- Auth UI

### Desktop Client (Rust + iced)
- SQLite schema (rusqlite/diesel)
- Metric entry and history views (iced)
- Sync engine
- Auth UI

---

## Planned Features

- **Export** — JSON, CSV, Markdown, PDF (preserves Obsidian compatibility)
- **Correlations** — Pearson r between metric pairs over a trailing 30-day window (schema already built, `correlation_snapshots` table exists)
- **Medication inventory** — calculated pill count from dose events + physical reconciliation (`medication_inventory_snapshots` table exists)
- **Trends** — week-over-week and month-over-month views per metric
- **Notifications** — missed dose alerts (Android WorkManager)
- **Multi-user** — schema is user-scoped throughout; single-user now, open to adding accounts later
- **Data migration** — import from existing Obsidian plugin JSON export

---

## Domain Rules

These rules are enforced in the Rails models and projectors, not in clients:

- Sleep events are attributed to the **wake date** (date of `sleep_end`), not the date sleep began
- Blood pressure wake and sleep readings are **never averaged together** — they are projected into separate `blood_pressure_wake` and `blood_pressure_sleep` summaries
- PRN medications can never have `missed` dose records
- Correlation projections require **≥ 14 matched days** to be considered valid
- All records are immutable once written; only `is_superseded` and `confirmation_status` may be updated on health events, and only `last_seen_at` and `is_active` on devices

---

## Sync Strategy

- Each client registers as a device and receives a token (returned once, stored locally)
- Every health event is tagged with the originating `device_id`
- On sync: client sends `last_synced_at`; server returns all events from other devices created after that timestamp
- Append-only design eliminates most conflicts — sync is nearly always additive
- Conflict edge case (same event amended on two offline devices): field-level merge, fall back to most-recent timestamp, device ID as tiebreaker (not yet implemented)
- `sync_cursors` table tracks per-device high-watermark (timestamp + event ID)
- `sync_logs` table provides immutable audit trail of every sync operation
