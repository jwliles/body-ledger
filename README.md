# Body Ledger

A personal health tracking PWA built around typed health records, an append-oriented event history, and Rails-backed reports. The current working system is a Rails API, PostgreSQL database, and installable Next.js web app deployed to a DigitalOcean droplet.

---

## Architecture

### Design Philosophy

- **Health records are ledger-like** — BP, sleep, activity, weight, and medication dose usage are recorded as events. Corrections are amendments instead of silent rewrites.
- **Medication administration is editable** — medication name, form, strength, prescription quantity, and related admin fields can be updated or merged because they describe the medication record, not a historical dose event.
- **Rails owns report logic** — dashboards aim for result parity with the old Datacore reports, while using normalized Rails models and services instead of Markdown/YAML queries.
- **Deployment is self-managed** — the production app runs on a DigitalOcean droplet with Cloudflare in front of the public domains.

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
| PWA client | Next.js 16 + React 19 + Tailwind CSS 4 + TypeScript 5 |
| Browser install | Web manifest + service worker |
| Auth | Custom username/password + TOTP (rotp, rqrcode, zxcvbn) |

**Supported client:** installable web PWA.

---

## Metric Types

| Metric | Key fields |
|--------|------------|
| Blood pressure | systolic, diastolic, pulse, reading_context (wake/sleep — never averaged together) |
| Weight | value_kg, original_unit, original_value |
| Sleep | sleep_start, sleep_end, sleep_minutes, duration/time-in-bed (derived); attributed to wake date |
| Activity | activity_type, duration_minutes, distance_km, steps, heart_rate_avg, calories_burned |
| Nutrition | meal_type, 7 macro columns, micronutrients (JSONB) |
| Symptom | symptom_code, severity (1–10), body_location |
| Medication dose | medication_id, dose_mg, dose_type (scheduled/prn/missed/reconciliation), timing_context (wake/sleep/other) |

---

## What's Built

### Backend — Rails API (live at `api.bodyledger.org`)

Rails API with PostgreSQL, typed payload tables, amendment support for health events, report services, CORS, and device-token auth (`Authorization: Bearer <token>`) on protected requests. Health events are amendment-based; medication administration records are editable.

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/auth/register` | Create user account |
| POST | `/api/v1/auth/login` | Validate credentials, return user info |
| POST | `/api/v1/auth/totp_setup` | Generate OTP secret and QR code |
| POST | `/api/v1/auth/totp_verify` | Verify TOTP code and enable 2FA |
| POST | `/api/v1/devices` | Register device, return token (shown once) |
| PATCH | `/api/v1/devices/:id` | Update last_seen_at / deactivate |
| GET | `/api/v1/health_events` | List events (filter: metric_type, date range, status) |
| POST | `/api/v1/health_events` | Create event + payload in one request; idempotent via client_uuid |
| GET | `/api/v1/health_events/:id` | Single event with payload |
| POST | `/api/v1/health_events/:id/amend` | Amend event; original marked superseded atomically |
| GET | `/api/v1/medications` | List user medications |
| POST | `/api/v1/medications` | Create medication |
| PATCH | `/api/v1/medications/:id` | Update editable medication administration fields |
| POST | `/api/v1/medications/:id/merge` | Reassign dose history from a duplicate medication and deactivate the duplicate |
| GET | `/api/v1/reports` | List Rails-backed dashboards |
| GET | `/api/v1/reports/:id` | Render a Rails-backed dashboard/report |
| GET | `/api/v1/summaries` | Daily summaries (triggers projectors on request) |
| POST | `/api/v1/sync` | Pull events from other devices since last_synced_at |

SHA-256 token digest stored in DB — O(1) indexed lookup, 256-bit entropy.

### PWA Client (`web/`)

- Auth page: login and signup tabs, TOTP input field
- Dashboard: health metrics, medication dose entry, BP/HR, weight, sleep, steps, editable records, medication administration update/merge flow
- Reports: Rails-backed dashboards recreated from the Datacore report results
- Manifest, install icons, and production service worker
- Catppuccin dark theme, Atkinson Hyperlegible font
- API URL configurable via `NEXT_PUBLIC_API_URL`

### Legacy Journal Import

The Rails app includes an importer for legacy Obsidian journal files. It imports available BP, sleep, weight, steps, and medication dose data into typed records. If a medication appears in dose history without prescription/admin metadata, the importer creates a placeholder medication that can later be edited or merged in the web UI.

---

## Getting Started

### Backend

```sh
cd server/health_tracker_api
bundle install
rails db:create db:migrate
rails s                        # → http://localhost:3000
```

### Web

```sh
cd web
npm install
# create web/.env.local with:
# NEXT_PUBLIC_API_URL=http://localhost:3000
npm run dev                    # → http://localhost:3000 (or next available port)
```

### Environment Variables

| Variable | Where | Purpose |
|----------|-------|---------|
| `HEALTH_TRACKER_API_DATABASE_PASSWORD` | Backend (production only) | PostgreSQL password |
| `ALLOWED_ORIGINS` | Backend (production only) | Comma-separated CORS origins |
| `NEXT_PUBLIC_API_URL` | Web | API base URL |

Production secrets live outside Git. The droplet convention is a root-only
`server/health_tracker_api/.env.production` file that is sourced before Rails commands
and referenced by the API systemd service.

Operational docs:

- `docs/operations/production.md`
- `docs/operations/journal_import.md`

---

## Next Steps

### PWA Client (remaining MVP work)
- History filters beyond the recent edit list
- Daily summary view
- Device management

---

## Planned Features

- **Export** — JSON, CSV, Markdown, PDF (preserves Obsidian compatibility)
- **Correlations** — Pearson r between metric pairs over a trailing 30-day window (schema already built, `correlation_snapshots` table exists)
- **Medication inventory** — calculated pill count from dose events + physical reconciliation (`medication_inventory_snapshots` table exists)
- **Trends** — week-over-week and month-over-month views per metric
- **Notifications** — PWA/browser medication reminders where platform support allows
- **Additional users** — schema is user-scoped, but current production use is single-user
- **Data migration** — journal frontmatter/body import from legacy Obsidian notes is implemented; broader exports/imports are still planned

---

## Domain Rules

These rules are enforced in the Rails models and projectors, not in clients:

- Sleep events are attributed to the **wake date** (date of `sleep_end`), not the date sleep began
- Sleep minutes are an explicit value when recorded by a tracker/manual entry; time-in-bed is derived from bedtime/wake time when both exist
- Blood pressure wake and sleep readings are **never averaged together** — they are projected into separate `blood_pressure_wake` and `blood_pressure_sleep` summaries
- Medication administration records are editable and mergeable; medication dose usage remains ledger/event history
- PRN medications can never have `missed` dose records
- Correlation projections require **≥ 14 matched days** to be considered valid
- Health metric and medication dose records are immutable once written; corrections are amendments. Administrative medication fields can be updated.

---

## Sync Strategy

The schema includes device records, sync cursors, and sync logs, and the API has a sync endpoint. The current client is the PWA; offline behavior beyond the production service worker is not implemented yet.

Planned sync behavior:

- Each browser/PWA install registers as a device and receives a token returned once and stored locally.
- Every health event is tagged with the originating `device_id`.
- Clients send `last_synced_at`; the server returns events from other devices created after that timestamp.
- Append-style event history should keep most sync operations additive.
- Conflicting offline amendments still need a resolution policy.
