# Legacy Journal Import

The journal importer migrates Obsidian daily notes into typed Rails records. It
is designed for result parity with the Datacore dashboards, not imitation of the
Markdown/YAML implementation.

## Source Data

The legacy journal path is copied onto the droplet before import. Production
examples have used:

```sh
/root/body-ledger/import/journal
```

The importer scans nested files matching `**/20*.md`.

## Dry Run

Dry run is explicit and should be run first:

```sh
cd /root/body-ledger/server/health_tracker_api
set -a
source .env.production
set +a

DRY_RUN=true USERNAME='jwl' JOURNAL_PATH='/root/body-ledger/import/journal' \
bin/rake body_ledger:import_journal
```

The output reports files scanned, records that would be created, skipped missing
fields, and bad timestamps.

## Real Import

The task defaults to dry-run behavior unless `DRY_RUN=false` is supplied:

```sh
DRY_RUN=false USERNAME='jwl' JOURNAL_PATH='/root/body-ledger/import/journal' \
bin/rake body_ledger:import_journal
```

Verify counts:

```sh
bin/rails runner 'u=User.find_by!(username: "jwl"); puts({events: u.health_events.count, current_events: u.health_events.current.count, meds: u.medications.count}.inspect); puts u.health_events.group(:metric_type).count.inspect'
```

## Imported Fields

- Wake/sleep BP fields become `blood_pressure` events with `reading_context`.
- `wake_meds` and `sleep_meds` become medication dose timing context.
- `sleep` becomes actual slept minutes.
- `bedtime` and `wake_time` describe time in bed when both exist.
- Weight is preserved as pounds in original value while Rails stores kg.
- Steps become daily activity records.

Bad timestamps are skipped rather than guessed.

## Medication Placeholders

Legacy notes often contain medication dose history without prescription/admin
metadata. The importer creates placeholder medications by normalized name so the
dose records have a stable foreign key.

Placeholders use generic values such as `1 unit` and should be enriched later
through the web UI. Editing a placeholder updates dashboard display for the
existing dose history because the medication ID remains the same.

If a duplicate medication exists, use the medication merge flow to move dose
payloads into the kept medication and deactivate the duplicate. The dose events
remain ledger history.
