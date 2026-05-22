---
age:
  - 38.1.16
age_unix: 1203359888
authors:
  - jwl
title: meds_dashboard
timestamp: 1760703644400
date_created: 2025-10-16T22:06:57
date_updated: 2025-10-21T10:16:53
hash: 66a8aa67d63eac68bc2eef332f0baf61b98a37eb25bbd5d3cf7d6b6e318de8c2
id: 3fef5f28-6027-4c93-8717-4c3ff6c2e70d
---

# meds_dashboard

## What These Tables Show

These tables track my prescription medications, daily doses, and adherence patterns.

### Basic Med Info

Shows current status of each medication:
- **Med**: Medication name
- **Taken**: Total doses taken from the prescription
- **Last Qty**: Number of doses in the most recent log
- **Last At**: Timestamp of the most recent dose

### Inventory & Refill Status

Tracks prescription inventory and calculates when refills are needed:
- **Rx Qty**: Total quantity prescribed
- **Taken**: Doses used so far
- **Remaining**: Doses left (Rx Qty − Taken)
- **Per Day**: Prescribed daily dosage
- **Days Left**: How many days the remaining supply will last (Remaining ÷ Per Day)
- **Next Refill**: Estimated date when a refill will be needed (today + Days Left)
- **⚠️ Flag**: "Refill soon" warning appears when ≤5 days remain

### Recent Dose Logs (Last 20)

Displays the most recent medication doses extracted from my daily journal entries (notes tagged `med-note`). Each entry shows:
- **Date**: Date the dose was taken (YYYY-MM-DD)
- **Time**: Time the dose was taken (HH:MM)
- **Med**: Medication name (matches the medication file title)
- **Qty**: Quantity taken (e.g., 1, 2, 0.5)

These logs come from `ad-meds` admonition blocks in journal notes with the format:

```go
- 2025-10-17 06:36 | med:: amlodipine | qty:: 1
- 2025-10-17 06:36 | med:: [[amlodipine]] | qty:: 1  (wikilinks are supported)
```

**Note**: The tracker now properly handles wikilinked medication names (e.g., `[[amlodipine]]` or `[[amlodipine]]`) and automatically strips the brackets for matching against medication file titles.

### Adherence Tracking

Calculates medication adherence rates over rolling time windows:
- **Med**: Medication name
- **Adherence 7d**: Percentage of prescribed doses taken in the last 7 days (or since started, if less than 7 days)
  - Formula: (actual doses taken ÷ expected doses) × 100
  - Expected = (days since date_started, max 7) × Per Day
- **Adherence 30d**: Same calculation over the last 30 days (or since started, if less than 30 days)
  - Expected = (days since date_started, max 30) × Per Day
- **Last Taken**: Timestamp of most recent dose (from medication file frontmatter)

**Note**: Adherence respects `date_started` in medication frontmatter, so newly started medications won't show artificially low adherence.

### How to Interpret

- **Adherence < 100%**: Missing doses or taking less than prescribed
- **Adherence = 100%**: Taking medication as prescribed
- **Adherence > 100%**: Taking more than the prescribed daily amount (check with doctor)
- **Days Left**: When this reaches 5 or fewer, plan to refill
- **Recent Logs**: Shows actual dosing patterns from journal entries

### Data Sources

- **Medication files**: Located in `/health/medications/` with frontmatter properties (`rx_qty`, `rx_per_day`, `taken_qty`, `last_taken_at`, etc.)
- **Journal entries**: Daily notes tagged `med-note` containing `ad-meds` blocks with dose logs
- **Tag filter**: Medication files must have `tags: [meds]` in frontmatter

```datacorejsx
const TAG_FILTER = "meds";

// Helper functions
const toNumber = (v) => {
  if (v == null) return null;
  if (typeof v === "number") return Number.isFinite(v) ? v : null;
  const n = Number(String(v).trim().replace(/,/g, ""));
  return Number.isFinite(n) ? n : null;
};

// Column definitions
const basicColumns = [
  { id: "med", title: "Medication", value: r => r.med },
  { id: "taken", title: "Taken", value: r => r.taken },
  { id: "last_qty", title: "Last Qty", value: r => r.last_qty },
  { id: "last_at", title: "Last At", value: r => r.last_at }
];

const inventoryColumns = [
  { id: "med", title: "Medication", value: r => r.med },
  { id: "rx_qty", title: "Rx Qty", value: r => r.rx_qty },
  { id: "taken", title: "Taken", value: r => r.taken },
  { id: "remaining", title: "Remaining", value: r => r.remaining },
  { id: "days_left", title: "Days Left", value: r => r.days_left },
  { id: "next_refill", title: "Next Refill", value: r => r.next_refill },
  { id: "flag", title: "⚠️", value: r => r.flag }
];

const formatDate = d => d ? d.replace(/-/g, '_') : d;

const logsColumns = [
  { id: "date", title: "Date", value: r => formatDate(r.date) },
  { id: "time", title: "Time", value: r => r.time },
  { id: "med", title: "Medication", value: r => r.med },
  { id: "qty", title: "Qty", value: r => r.qty }
];

const adherenceColumns = [
  { id: "med", title: "Medication", value: r => r.med },
  { id: "adherence_7d", title: "Adherence 7d", value: r => r.adherence_7d },
  { id: "adherence_30d", title: "Adherence 30d", value: r => r.adherence_30d },
  { id: "last_taken", title: "Last Taken", value: r => r.last_taken }
];

return function View() {
  let pages = dc.useQuery("@page");
  const [allLogs, setAllLogs] = dc.useState([]);
  const [isLoading, setIsLoading] = dc.useState(true);

  // Filter for meds
  let meds = pages.filter(p => {
    const medsProperty = p.value && p.value("meds");
    const tags = p.value && p.value("tags");

    if (medsProperty === true) return true;
    if (tags && Array.isArray(tags) && tags.indexOf(TAG_FILTER) !== -1) return true;
    if (tags && String(tags).split(/[,\s]+/).indexOf(TAG_FILTER) !== -1) return true;
    return false;
  });

  // Get journal pages with med-note tag
  const journalPages = pages.filter(p => {
    const tags = p.value && p.value("tags");
    const hasMedNoteTag = Array.isArray(tags) ? tags.includes("med-note")
      : tags ? String(tags).split(/[,\s]+/).includes("med-note") : false;

    return hasMedNoteTag;
  });

  // Parse journal files asynchronously
  dc.useEffect(() => {
    async function parseLogs() {
      const logs = [];

      for (const p of journalPages) {
        try {
          // Use $path for DatacoreJSX page objects
          const filePath = p.$path || (p.file && p.file.path);
          if (!filePath) continue;

          const tfile = app.vault.getAbstractFileByPath(filePath);
          if (!tfile) continue;

          const content = await app.vault.read(tfile);

          // Match lines like: - 2025-10-17 06:36 | med:: [[amlodipine]] | qty:: 1
          // Strips wikilinks like [[med]] or [[med]]
          const re = /(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2}).*?\bmed::\s*([^\|]+?)\s*\|\s*qty::\s*([0-9.]+)/g;
          let m;
          while ((m = re.exec(content)) !== null) {
            // Strip wikilinks: [[med]] -> med, [[med]] -> med
            const medName = m[3].trim().replace(/\[\[/g, '').replace(/\]\]/g, '');
            logs.push({
              date: m[1],
              time: m[2],
              dt: window.moment(m[1] + " " + m[2], "YYYY-MM-DD HH:mm"),
              med: medName,
              qty: Number(m[4])
            });
          }
        } catch (e) {
          // Skip files that can't be read
        }
      }

      setAllLogs(logs);
      setIsLoading(false);
    }

    parseLogs();
  }, [journalPages.length]);

  // ========== TABLE 1: Basic Med Info ==========
  const basicRows = meds.map(p => ({
    med: p.value("title") ?? (p.file && p.file.basename) ?? "—",
    taken: toNumber(p.value("taken_qty")) ?? 0,
    last_qty: p.value("last_taken_qty") ?? "—",
    last_at: p.value("last_taken_at") ?? "—"
  }));

  // ========== TABLE 2: Inventory & Refill Status ==========
  const inventoryRows = meds.map(p => {
    const name = p.value("title") ?? (p.file && p.file.basename) ?? "—";
    const qty = toNumber(p.value("rx_qty")) ?? 0;
    const perDay = toNumber(p.value("rx_per_day")) ?? 1;
    const taken = toNumber(p.value("taken_qty")) ?? 0;
    const remaining = Math.max(0, qty - taken);
    const daysLeft = perDay > 0 ? remaining / perDay : Infinity;
    const eta = perDay > 0 ? window.moment().add(daysLeft, "days").format("YYYY-MM-DD") : "—";
    const flag = perDay > 0 && remaining <= perDay * 5 ? "⚠️ Refill soon" : "";

    return {
      med: name,
      rx_qty: qty,
      taken: taken,
      remaining: remaining,
      days_left: Math.floor(daysLeft),
      next_refill: eta,
      flag: flag
    };
  });

  // ========== TABLE 3: Recent Dose Logs ==========
  const recentLogs = allLogs
    .sort((a,b) => (a.date + a.time < b.date + b.time ? 1 : -1))
    .slice(0, 20)
    .map(x => ({
      date: x.date,
      time: x.time,
      med: x.med,
      qty: x.qty
    }));

  // ========== TABLE 4: Adherence Tracking ==========
  // Calculate n days ago - we want the start of today minus n full days
  // For "last 7 days" we want Oct 11-17, so we need to go back to start of Oct 11
  const sinceDays = (n) => window.moment().subtract(n - 1, 'days').startOf('day');

  const adherenceRows = meds.map(p => {
    const name = p.value("title") ?? (p.file && p.file.basename) ?? "—";
    const perDay = toNumber(p.value("rx_per_day")) ?? 1;
    const dateStarted = p.value("date_started");

    // Calculate the actual window start based on date_started
    // Convert Datacore DateTime to string first (Datacore returns Luxon DateTime objects)
    const startDate = dateStarted ? window.moment(String(dateStarted).split('T')[0]) : null;
    const windowStart7 = startDate ? window.moment.max(sinceDays(7), startDate) : sinceDays(7);
    const windowStart30 = startDate ? window.moment.max(sinceDays(30), startDate) : sinceDays(30);

    // Filter logs to only include doses since the later of (window start, date_started)
    const last7 = allLogs.filter(x => x.med === name && x.dt.isAfter(windowStart7));
    const last30 = allLogs.filter(x => x.med === name && x.dt.isAfter(windowStart30));

    const got7 = last7.reduce((sum, x) => sum + Number(x.qty || 0), 0);
    const got30 = last30.reduce((sum, x) => sum + Number(x.qty || 0), 0);

    // Calculate days in window since medication was started
    const daysSinceStart7 = startDate ?
      Math.min(7, window.moment().diff(startDate, 'days') + 1) : 7;
    const daysSinceStart30 = startDate ?
      Math.min(30, window.moment().diff(startDate, 'days') + 1) : 30;

    const need7 = daysSinceStart7 * perDay;
    const need30 = daysSinceStart30 * perDay;

    const a7 = need7 > 0 ? Math.round(100 * got7 / need7) : 0;
    const a30 = need30 > 0 ? Math.round(100 * got30 / need30) : 0;

    return {
      med: name,
      adherence_7d: a7 + "%",
      adherence_30d: a30 + "%",
      last_taken: p.value("last_taken_at") ?? "—"
    };
  });

  return (
    <div>
      <h3>Medication Tracker</h3>
      <p>Found {meds.length} medications, {journalPages.length} journal pages</p>

      <h3>Basic Med Info</h3>
      <dc.Table columns={basicColumns} rows={basicRows} />

      <h3>Inventory & Refill Status</h3>
      <dc.Table columns={inventoryColumns} rows={inventoryRows} />

      <h3>Recent Dose Logs</h3>
      {isLoading ? (
        <p>Loading dose logs...</p>
      ) : recentLogs.length > 0 ? (
        <dc.Table columns={logsColumns} rows={recentLogs} />
      ) : (
        <p>No dose logs found ({allLogs.length} total logs parsed)</p>
      )}

      <h3>Adherence Tracking</h3>
      {isLoading ? (
        <p>Loading adherence data...</p>
      ) : (
        <dc.Table columns={adherenceColumns} rows={adherenceRows} />
      )}
    </div>
  );
};
```
