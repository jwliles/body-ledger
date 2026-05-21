---
name: body_ledger project context
description: Current status and next steps for the body_ledger health tracker
type: project
---

## Rails API — Complete and Running

- Live at https://api.bodyledger.org (nginx + Let's Encrypt SSL, Rails on port 3000 via systemd)
- Droplet: 165.245.165.96, user: root, path: /root/body-ledger/server/health_tracker_api
- PostgreSQL: production DB is `health_tracker_api_production`, user `health_tracker_api`, password in systemd service as HEALTH_TRACKER_API_DATABASE_PASSWORD
- ALLOWED_ORIGINS set in systemd: http://localhost:3000,https://bodyledger.org
- User created: jwl / 9InchNailsSince1903! / America/Chicago
- Device registered (id:1, token saved), TOTP verified and enabled

## Auth Design

- Username-based login (case-sensitive, no length limit, letters/digits/underscores/hyphens, must start with letter or digit)
- Email optional (privacy — only for account recovery)
- Password rules: uppercase, lowercase, digit, special char, first/last char different types, zxcvbn score ≥ 3
- zxcvbn gem installed for entropy checking

## DNS (Cloudflare)

- api.bodyledger.org → 165.245.165.96
- bodyledger.org → 165.245.165.96 (reserved for Web UI)

## Landing Page

- Dark mode static HTML at public/index.html in the Rails app
- Uses Atkinson Hyperlegible Next font (Google Fonts)

## Web UI — In Progress

- Framework: Next.js + Tailwind CSS, Catppuccin Mocha theme
- Location in repo: web/
- Login page built and working — stores device_token and device_id in localStorage
- API URL set via NEXT_PUBLIC_API_URL=https://api.bodyledger.org in web/.env.local

## Web UI — Next Steps

1. Add password visibility toggle to login form
2. Decide on registration flow: "claim" model (enter username, if unused you get it) vs separate register page
3. Build dashboard (redirect target after login)

## Key architecture decisions
- Append-only event sourcing: no deletes, no overwrites, amendments are new records
- health_events is the universal envelope; per-metric payload tables join 1:1 via health_event_id as PK+FK
- Metric type = VARCHAR + CHECK (not PG enum) for easy migration widening
- is_superseded denormalized flag with partial index for fast current-only queries
- client_uuid UUID UNIQUE per user for idempotent inserts
- No updated_at on health_events; ImmutableRecord concern raises on update except is_superseded and confirmation_status
- BP aggregates ALWAYS split by reading_context (wake/sleep) — enforced in BloodPressureProjector

## User Notes

- User has photophobia (light sensitivity from concussion) — dark mode is essential
- User is familiar with Obsidian and has made custom themes — comfortable with dark color schemes
- User is learning Tailwind CSS through this project
- User may release the project publicly if it goes well
