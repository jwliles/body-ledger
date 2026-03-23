# New Architecture — Health Tracker Migration

## Status
**Planning phase.** Obsidian plugin is complete and deployed. New stack decided, not yet started.
Next step: design Rails schema (event sourcing based).

## Why Migrating
- Obsidian mobile is clunky for health logging
- Obsidian Sync has latency and potential data conflicts
- Android is better suited as primary logging device (notifications, Health Connect)
- Want a standalone app not tied to Obsidian
- Project has potential for public release

## Target Stack

| Layer | Technology | Notes |
|-------|------------|-------|
| Desktop UI | Rust + iced | Wayland-native on KDE, familiar to user |
| Android UI | Kotlin (native Android) | WorkManager, Health Connect, full platform access |
| Backend/sync | Rails API + PostgreSQL | Business logic lives here |
| Desktop local DB | rusqlite + sqlx or diesel | Offline-first SQLite |
| Android local DB | Room | Offline-first SQLite |
| Auth | Devise + devise-two-factor | MFA, single user now, open to multi-user |

## Client Architecture (Thin Clients — Blazor-style)
- Clients send raw event data to Rails
- Rails computes everything (adherence, trends, correlations, summaries)
- Clients render returned results
- Local SQLite is a cache/offline buffer, not the source of truth
- Business logic fixed in one place (Rails), applies everywhere

## Data Model — Append-Only Event Ledger
Inspired by double-entry bookkeeping / event sourcing:

- **No deletes** — ever
- **No overwrites** — records are immutable once written
- **Amendments** are new records that reference the original event (`supersedes_id`)
- **Current state** is computed from the full event log (projections/snapshots)
- **Reconciliation** — physical count vs calculated state (already in Obsidian plugin for meds)
- Every record carries `device_id`, `created_at`, `occurred_at`, `supersedes_id`

### Analogy
| Accounting | Health Data |
|------------|-------------|
| Journal entry | Health event (BP reading, dose taken) |
| Ledger | Append-only event log |
| Adjusting entry | Amendment event referencing original |
| Trial balance | Computed current state |
| Reconciliation | Physical pill count vs calculated inventory |

## Sync Strategy
- Each device registers with server, gets a device token
- Every record tagged with `device_id`
- Sync: client sends `device_id` + `last_synced_at`, gets all changes from other devices
- Append-only model nearly eliminates conflicts — sync is mostly just appending
- True conflicts (same record amended on two offline devices): field-level merge first, fall back to most-recent `updated_at` wins, device ID as tiebreaker
- Soft deletes only (cancellation events, not SQL deletes)

## Export Formats (planned)
- **Shared/easy:** JSON, CSV, YAML, Markdown
- **Platform-specific:** PDF (Android PdfDocument / JVM iText), Word (JVM Apache POI, desktop only initially)
- Markdown export preserves Obsidian compatibility if desired

## Domain Model (from Obsidian plugin — carry forward)
Health event types: blood_pressure, weight, sleep, activity, nutrition, symptom, medication_dose
Key rules:
- Sleep attributed to wake date (sleep_end date)
- BP wake/sleep stored separately, never averaged
- PRN meds never marked "missed"
- Correlation requires ≥14 matched days
- Adherence engine replays transactions to compute inventory

## User's Relevant Skills
- Kotlin: comfortable (Android project, this plugin)
- Rust: comfortable (crates, CLI, GUI with egui/iced/Tauri/Leptos, backend, TUI)
- Rails: comfortable (portfolio site backend)
- TypeScript: comfortable (this plugin)
- Go, Python: comfortable

## Repos (not yet created)
- `health_tracker_api` — Rails backend
- `health_tracker_android` — Kotlin Android
- `health_tracker_desktop` — Rust + iced

## Next Steps
1. Design Rails schema (PostgreSQL, event sourcing based)
2. Design API endpoints
3. Scaffold Rails project
4. Android client
5. Desktop client (iced)
6. Data migration from Obsidian plugin JSON files
