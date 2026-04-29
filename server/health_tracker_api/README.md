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
- **Device token auth** — SHA-256 digest stored in DB (not bcrypt); 256-bit entropy raw token returned once at device registration
- **Projectors** — materialize `daily_summaries` from the event log for all 7 metric types
- **Append-only sync** — clients pull events from other devices via `POST /api/v1/sync`
