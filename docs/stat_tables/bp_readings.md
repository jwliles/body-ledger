---
age:
  - 38.1.14
age_unix: 1203182457
authors:
  - jwl
title: bp_readings
timestamp: 1760490519318
date_created: 2025-10-14T20:08:39
date_updated: 2025-10-21T10:16:53
hash: e0895bd5ae891c3767cf141c735494db4db75c6e70f01f77f7105c78be424a87
id: 205b8c8f-b1ea-40f4-a190-86683f9755a0
tags:
  - averages_systems
  - blood_pressure
  - bp_monitoring
  - daily_records
  - health_tracking
  - medication_timing
  - pulse_measurements
---

# bp_readings

## What These Tables Show

These tables analyze my **blood pressure readings** in relation to **medication timing** and provide a **chronological view** of recent readings.

### Before/After Medication Analysis

- **Before/After** indicates whether the measurement was taken **before** or **after** taking medication (based on timestamps in each daily note).
- **Δ mins (BP − Med)** shows how many minutes separated the blood pressure reading from the medication time. Negative numbers mean the reading came before meds; positive numbers mean after.
- **Avg Sys / Avg Dia / Avg Pulse** are the average systolic, diastolic, and pulse values for each group.
- **N** shows how many readings are included in each average.
- Color styling from my theme highlights blood pressure levels:
  - `.bp-high` (red or keyword color) marks elevated readings.
  - `.bp-low` (blue or string color) marks unusually low readings.

Together, these let me see whether my blood pressure trends higher or lower after medication, both **in the morning (Wake)** and **at night (Sleep)**.

### Recent Readings (Last 30 Days)

A chronological table showing all Wake and Sleep readings from the past 30 days, including:
- **Date & Time**: When the reading was taken
- **Systolic/Diastolic**: Blood pressure values
- **Pulse Pressure**: The difference between systolic and diastolic (Sys - Dia), which is an indicator of arterial stiffness. Normal range is 40-60 mmHg.
- **Pulse**: Heart rate at time of measurement

```datacorejsx
// === BP vs Meds: Before/After with MIN/MAX coloring (compat-safe) ===
const TAG_FILTER = "med-note";
const EXCLUDE_PREFIX = "templates/";

// Helpers
const TakenBadge = t => <span className={"taken-badge taken-" + t.toLowerCase()}>{t}</span>;
const toNum = v => (v == null ? null : Number(v));
const formatDate = d => d ? d.replace(/-/g, '_') : d;
const toMin = (a,b) => Math.round((new Date(a) - new Date(b)) / 60000); // <0 = Before
const avg = arr => (arr && arr.length ? Math.round(arr.reduce((x,y)=>x+y) / arr.length) : null);
const groupBy = (rows, key) => {
  const m = {};
  for (const r of rows) {
    const k = r[key];
    if (!m[k]) m[k] = [];
    m[k].push(r);
  }
  return m;
};
const pageDateYMD = (p) => {
  try {
    // First try to extract date from filename (e.g., "2025_10_18" -> "2025-10-18")
    const name = p.$name || "";
    const dateMatch = name.match(/(\d{4})_(\d{2})_(\d{2})/);
    if (dateMatch) {
      return `${dateMatch[1]}-${dateMatch[2]}-${dateMatch[3]}`;
    }

    // Fallback to title property if it has date format
    const title = p.value && p.value("title");
    if (title) {
      const titleMatch = String(title).match(/(\d{4})_(\d{2})_(\d{2})/);
      if (titleMatch) {
        return `${titleMatch[1]}-${titleMatch[2]}-${titleMatch[3]}`;
      }
    }

    // Last resort: use date_created
    const fm = p.value && p.value("date_created");
    if (fm) {
      const d = new Date(String(fm).replace(/T(\d{2})-(\d{2})-(\d{2})/, "T$1:$2:$3"));
      if (!isNaN(d)) return d.toISOString().slice(0, 10);
    }
    if (p.$ctime) {
      const d = new Date(p.$ctime);
      if (!isNaN(d)) return d.toISOString().slice(0, 10);
    }
  } catch { }
  return p.$name || "—";
};
const byDateName = (a,b) => String(a.date).localeCompare(String(b.date));
const byDateNameDesc = (a,b) => String(b.date).localeCompare(String(a.date)); // newest to oldest
const num = v => <span className="num">{v}</span>;

const buildRows = (pages, sysKey, diaKey, pulseKey, bpTimeKey, medsTimeKey) => {
  const out = [];
  for (const p of pages) {
    // Require BP data, but allow missing medication timing
    if (!(p.value && p.value(sysKey)!=null && p.value(diaKey)!=null)) continue;
    const sys = toNum(p.value(sysKey));
    const dia = toNum(p.value(diaKey));
    const pulse = p.value(pulseKey)!=null ? toNum(p.value(pulseKey)) : null;

    // Calculate timing delta only if both timestamps exist
    let diffMins = null;
    let taken = "—";
    if (p.value(bpTimeKey) && p.value(medsTimeKey)) {
      diffMins = toMin(p.value(bpTimeKey), p.value(medsTimeKey));
      taken = diffMins < 0 ? "Before" : "After";
    }

    out.push({
      date: pageDateYMD(p),
      sys, dia, pulse,
      diffMins,
      taken,
    });
  }
  return out;
};

const summarize = rows => {
  // Filter out rows without medication timing data
  const validRows = rows.filter(r => r.taken !== "—");
  const g = groupBy(validRows, "taken");
  const out = [];
  for (const k in g) {
    const items = g[k];
    out.push({
      taken: k,
      n: items.length,
      avgSys:   avg(items.map(i=>i.sys)),
      avgDia:   avg(items.map(i=>i.dia)),
      avgPulse: items.every(i=>i.pulse!=null) ? avg(items.map(i=>i.pulse)) : null,
      avgDelta: avg(items.map(i=>i.diffMins)),
    });
  }
  return out;
};

return function View() {
  // Query pages
  let pages = dc.useQuery("@page");
  if (TAG_FILTER) {
    pages = pages.filter(p => {
      const t = p.value && p.value("tags");
      if (!t) return false;
      if (Array.isArray(t)) return t.indexOf(TAG_FILTER) !== -1;
      return String(t).split(/[,\s]+/).indexOf(TAG_FILTER) !== -1;
    });
  }
  pages = pages.filter(p => !((p.$path || "").startsWith(EXCLUDE_PREFIX)));

  // Build rows
  const amRows = buildRows(pages, "am_sys","am_dia","am_hr","am_bp_time","am_meds");
  const pmRows = buildRows(pages, "pm_sys","pm_dia","pm_hr","pm_bp_time","pm_meds");

  // Summaries
  const amSummary = summarize(amRows);
  const pmSummary = summarize(pmRows);

  // Extremes (details)
  const pmMinSys = pmRows.length ? Math.min.apply(null, pmRows.map(r=>r.sys)) : null;
  const pmMaxSys = pmRows.length ? Math.max.apply(null, pmRows.map(r=>r.sys)) : null;
  const pmMinDia = pmRows.length ? Math.min.apply(null, pmRows.map(r=>r.dia)) : null;
  const pmMaxDia = pmRows.length ? Math.max.apply(null, pmRows.map(r=>r.dia)) : null;

  const amMinSys = amRows.length ? Math.min.apply(null, amRows.map(r=>r.sys)) : null;
  const amMaxSys = amRows.length ? Math.max.apply(null, amRows.map(r=>r.sys)) : null;
  const amMinDia = amRows.length ? Math.min.apply(null, amRows.map(r=>r.dia)) : null;
  const amMaxDia = amRows.length ? Math.max.apply(null, amRows.map(r=>r.dia)) : null;

  // Extremes (summaries)
  const pmSysMax = pmSummary.length ? Math.max.apply(null, pmSummary.map(s=>s.avgSys==null?-1e9:s.avgSys)) : null;
  const pmSysMin = pmSummary.length ? Math.min.apply(null, pmSummary.map(s=>s.avgSys==null?1e9:s.avgSys)) : null;
  const pmDiaMax = pmSummary.length ? Math.max.apply(null, pmSummary.map(s=>s.avgDia==null?-1e9:s.avgDia)) : null;
  const pmDiaMin = pmSummary.length ? Math.min.apply(null, pmSummary.map(s=>s.avgDia==null?1e9:s.avgDia)) : null;

  const amSysMax = amSummary.length ? Math.max.apply(null, amSummary.map(s=>s.avgSys==null?-1e9:s.avgSys)) : null;
  const amSysMin = amSummary.length ? Math.min.apply(null, amSummary.map(s=>s.avgSys==null?1e9:s.avgSys)) : null;
  const amDiaMax = amSummary.length ? Math.max.apply(null, amSummary.map(s=>s.avgDia==null?-1e9:s.avgDia)) : null;
  const amDiaMin = amSummary.length ? Math.min.apply(null, amSummary.map(s=>s.avgDia==null?1e9:s.avgDia)) : null;

  // Columns
  const Sleep_SUMMARY_COLS = [
    { id: "taken",  title: "Taken",   value: r => TakenBadge(r.taken) },
    { id: "n",      title: "N",       value: r => num(r.n) },
    { id: "avgSys", title: "Average Systolic",
      value: r => <span className={"num " + (r.avgSys===pmSysMax?"bp-high":(r.avgSys===pmSysMin?"bp-low":""))}>{r.avgSys==null?"—":r.avgSys}</span> },
    { id: "avgDia", title: "Average Diastolic",
      value: r => <span className={"num " + (r.avgDia===pmDiaMax?"bp-high":(r.avgDia===pmDiaMin?"bp-low":""))}>{r.avgDia==null?"—":r.avgDia}</span> },
    { id: "avgPulse", title: "Average Pulse", value: r => num(r.avgPulse==null?"—":r.avgPulse) },
    { id: "avgDelta", title: "Average Delta (minutes)", value: r => num(r.avgDelta==null?"—":r.avgDelta) },
  ];

  const Sleep_DETAIL_COLS = [
    { id: "date",  title: "Date",  value: r => formatDate(r.date) },
    { id: "taken", title: "Taken", value: r => r.taken === "—" ? "—" : TakenBadge(r.taken) },
    { id: "bp",    title: "Systolic/Diastolic",
      value: r => (
        <span className="num">
          <span className={(r.sys===pmMaxSys)?"bp-high":(r.sys===pmMinSys)?"bp-low":""}>{r.sys}</span>/
          <span className={(r.dia===pmMaxDia)?"bp-high":(r.dia===pmMinDia)?"bp-low":""}>{r.dia}</span>
        </span>
      )
    },
    { id: "pulse",    title: "Pulse",              value: r => num(r.pulse==null?"—":r.pulse) },
    { id: "diffMins", title: "Delta (minutes) Blood Pressure - Medications", value: r => r.diffMins===null ? "—" : num(r.diffMins) },
  ];

  const Wake_SUMMARY_COLS = [
    { id: "taken",  title: "Taken",   value: r => TakenBadge(r.taken) },
    { id: "n",      title: "N",       value: r => num(r.n) },
    { id: "avgSys", title: "Average Systolic",
      value: r => <span className={"num " + (r.avgSys===amSysMax?"bp-high":(r.avgSys===amSysMin?"bp-low":""))}>{r.avgSys==null?"—":r.avgSys}</span> },
    { id: "avgDia", title: "Average Diastolic",
      value: r => <span className={"num " + (r.avgDia===amDiaMax?"bp-high":(r.avgDia===amDiaMin?"bp-low":""))}>{r.avgDia==null?"—":r.avgDia}</span> },
    { id: "avgPulse", title: "Average Pulse", value: r => num(r.avgPulse==null?"—":r.avgPulse) },
    { id: "avgDelta", title: "Average Delta (minutes)", value: r => num(r.avgDelta==null?"—":r.avgDelta) },
  ];

  const Wake_DETAIL_COLS = [
    { id: "date",  title: "Date",  value: r => formatDate(r.date) },
    { id: "taken", title: "Taken", value: r => r.taken === "—" ? "—" : TakenBadge(r.taken) },
    { id: "bp",    title: "Systolic/Diastolic",
      value: r => (
        <span className="num">
          <span className={(r.sys===amMaxSys)?"bp-high":(r.sys===amMinSys)?"bp-low":""}>{r.sys}</span>/
          <span className={(r.dia===amMaxDia)?"bp-high":(r.dia===amMinDia)?"bp-low":""}>{r.dia}</span>
        </span>
      )
    },
    { id: "pulse",    title: "Pulse",              value: r => num(r.pulse==null?"—":r.pulse) },
    { id: "diffMins", title: "Delta (minutes) Blood Pressure - Medications", value: r => r.diffMins===null ? "—" : num(r.diffMins) },
  ];

  // ===== RECENT READINGS (Last 30 Days) =====
  const buildRecentReadings = (pages, days = 30) => {
    const cutoff = Date.now() - days * 24 * 60 * 60 * 1000;
    const readings = [];
    const seen = new Set(); // Deduplicate by page path

    for (const p of pages) {
      const pagePath = p.$path || p.$name;
      if (seen.has(pagePath)) continue; // Skip duplicate pages
      seen.add(pagePath);

      const dateStr = pageDateYMD(p);
      const dateMs = new Date(dateStr).getTime();
      if (dateMs < cutoff) continue;

      const amSys = toNum(p.value && p.value("am_sys"));
      const amDia = toNum(p.value && p.value("am_dia"));
      const amPulse = toNum(p.value && p.value("am_hr"));
      const pmSys = toNum(p.value && p.value("pm_sys"));
      const pmDia = toNum(p.value && p.value("pm_dia"));
      const pmPulse = toNum(p.value && p.value("pm_hr"));

      if (amSys != null && amDia != null) {
        readings.push({
          date: dateStr,
          time: "Wake",
          sys: amSys,
          dia: amDia,
          pulse: amPulse,
          sortKey: dateStr + "A"
        });
      }
      if (pmSys != null && pmDia != null) {
        readings.push({
          date: dateStr,
          time: "Sleep",
          sys: pmSys,
          dia: pmDia,
          pulse: pmPulse,
          sortKey: dateStr + "P"
        });
      }
    }

    return readings.sort((a,b) => b.sortKey.localeCompare(a.sortKey));
  };

  const recentReadings = buildRecentReadings(pages, 30);

  const RECENT_COLS = [
    { id: "date", title: "Date", value: r => formatDate(r.date) },
    { id: "time", title: "Time", value: r => r.time },
    { id: "sys", title: "Systolic", value: r => num(r.sys) },
    { id: "dia", title: "Diastolic", value: r => num(r.dia) },
    { id: "pp", title: "Pulse Pressure", value: r => num(r.sys - r.dia) },
    { id: "pulse", title: "Pulse", value: r => r.pulse != null ? num(r.pulse) : "—" }
  ];

  return (
    <div>
      <h3>Sleep (Night) — Before/After vs Night Meds</h3>
      <dc.Table columns={Sleep_SUMMARY_COLS} rows={pmSummary} />
      <dc.Table columns={Sleep_DETAIL_COLS}   rows={pmRows.slice().sort(byDateNameDesc)} />

      <h3>Wake (Morning) — Before/After vs Morning Meds</h3>
      <dc.Table columns={Wake_SUMMARY_COLS} rows={amSummary} />
      <dc.Table columns={Wake_DETAIL_COLS}   rows={amRows.slice().sort(byDateNameDesc)} />

      <h3>Recent Readings (Last 30 Days)</h3>
      <dc.Table columns={RECENT_COLS} rows={recentReadings} />
    </div>
  );
}
```
