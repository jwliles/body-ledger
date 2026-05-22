# Body Ledger — Rails API

Rails 8.1 + PostgreSQL backend and sync hub for Body Ledger. Live at `api.bodyledger.org`.

## Running Locally

```sh
# Requires Ruby 3.4.2 (.ruby-version)
bundle install
rails db:create db:migrate
rails s    # → http://localhost:3000
```

## Environment Variables

| Variable | Required | Purpose |
|----------|----------|---------|
| `HEALTH_TRACKER_API_DATABASE_PASSWORD` | Production only | PostgreSQL password |
| `ALLOWED_ORIGINS` | Production only | Comma-separated CORS origins |

For production, keep these in a root-only `.env.production` file outside Git and source
that file before one-off Rails commands:

```sh
set -a
source .env.production
set +a
```

## Stack

| | |
|---|---|
| Framework | Rails 8.1.2 |
| Database | PostgreSQL |
| Auth | BCrypt (`has_secure_password`) + rotp (TOTP) |
| Password strength | zxcvbn |
| QR codes | rqrcode |
| CORS | rack-cors |

## Key Design Decisions

- **Immutable records** — health events are never deleted or overwritten; amendments reference originals via `supersedes_id`
- **Editable medication administration** — medication reference/admin fields can be updated; dose usage remains event history
- **Device token auth** — SHA-256 digest stored in DB (not bcrypt); 256-bit entropy raw token returned once at device registration
- **Projectors** — materialize `daily_summaries` from the event log for all 7 metric types
- **Append-style sync model** — browser/PWA installs are represented as devices; the sync endpoint exists for future offline behavior

## Operational Tasks

### Journal Import

```sh
DRY_RUN=true USERNAME='jwl' JOURNAL_PATH='/root/body-ledger/import/journal' \
bin/rake body_ledger:import_journal

DRY_RUN=false USERNAME='jwl' JOURNAL_PATH='/root/body-ledger/import/journal' \
bin/rake body_ledger:import_journal
```

The importer creates placeholder medications when legacy dose records only contain
a name. Those medication records are meant to be enriched later through the web UI.

### Medication Admin

| Method | Endpoint | Purpose |
|---|---|---|
| `GET` | `/api/v1/medications` | List medications |
| `POST` | `/api/v1/medications` | Create medication |
| `PATCH` | `/api/v1/medications/:id` | Update medication admin fields |
| `POST` | `/api/v1/medications/:id/merge` | Move dose history from a duplicate into the kept medication |
