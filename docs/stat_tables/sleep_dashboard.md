---
age:
  - 38.1.2
age_unix: 1202091296
authors:
  - jwl
title: sleep_dashboard
timestamp: 1759406504071
date_created: 2025-10-02T07:01:44
date_updated: 2025-10-21T10:16:53
hash: 61fab82b0303bb43d26d6eff2453bb5d86306373cb84fe0d51defc9c401319ed
id: 833642b8-b1e2-47ba-a4c2-7e6d8722435c
tags:
  - sleep_analysis
  - sleep_blood_pressure
  - sleep_metrics
  - sleep_quality
  - sleep_tracking
  - strain_type_effects
  - trazodone_steps
---

# sleep_dashboard

## What this dashboard shows

## Goal

Connect what I **took at night** (e.g., trazodone) to what happened **after that night**: sleep, steps, and blood pressure.

## How it works

- Each night has a recorded **med** (the specific medication I took) and **med_type** (its category).
- The query links **yesterday night's medication** → to **today's outcomes**:
    - Sleep minutes (total sleep from that night).
    - Morning BP (Wake) and evening BP (Sleep) from today.
    - Steps and quantity (dose count) from today.
- This "next-day" link matters because sleep and Wake vitals are recorded **the morning after** the dose.

## What the tables compare

There are three tables shown:

1. **By medication** (each specific item, e.g., "Trazodone").
2. **By med_type** (the broader category, e.g., "oral tablet").
3. **Sleep Efficiency Analysis** (last 30 days).

For each row (medication or type) the table calculates averages from all linked days.

## What the columns mean

- **Label**–The medication (or the medication type).
- **Avg Sleep**–Average minutes slept for nights linked to this medication/type.
- **Avg Qty**–Average quantity/dose count recorded the next day.
- **Avg Systolic / Avg Diastolic**–Average blood pressures across **Wake and Sleep** readings on those days (only counted when both sys and dia are present for a reading).
- **Avg Steps**–Average steps for those days.
- **Nights**–Number of nights that were linked to this medication/type and had a next-day note to summarize (so the outcomes exist).
- **BP Reads**–Number of paired BP readings used in the averages (systolic + diastolic entries).

## Badges and colors (to read the tables fast)

- **Badges**: "High" or "Low" appear next to the **highest** and **lowest** values **within each table** for that column (per-table extremes).
- **Colors**:
    - **bp-high** highlights the highest BP average in that table.
    - **bp-low** highlights the lowest BP average in that table.
        These are visual cues only; they're not clinical thresholds.

## Why track it this way

- It matches real-world timing: a **night dose** affects the **next morning's** sleep/BP, not the note from the same calendar day.
- It separates **Wake** and **Sleep** BP, so we can see if effects differ by time of day.
- Grouping by **medication** and **med_type** shows both specific and category-level patterns.

## Caveats

- **"Nights"** only counts nights that have a **next-day note** (so tonight's dose shows up tomorrow).
- Averages ignore missing data (e.g., if one day has sleep but no BP).
- Badges mark the highest/lowest **in the table**, not "good" vs "bad."

## How to interpret

- Compare **Avg Sleep** and **Avg BP** across medications/types.
- Look for consistent shifts (e.g., one medication linked with **lower Wake BP** or **more sleep**).
- Use the **Nights** and **BP Reads** counts to gauge reliability (bigger numbers = more confidence).

## Sleep Efficiency

The third table shows **sleep efficiency** for the last 30 days:
- **Sleep Efficiency** = (Sleep Duration ÷ Time in Bed) × 100%
- **Target**: ≥85% is considered good sleep efficiency
- **75-84%**: Fair efficiency (may indicate sleep issues)
- **<75%**: Poor efficiency (discuss with doctor)
- Shows average, minimum, and maximum efficiency with dates
- Low efficiency may indicate difficulty falling asleep, staying asleep, or excessive time in bed awake

```datacorejsx
// === Sleep & BP dashboard (Wake/Sleep-aware) with badges + min/max coloring ===
// Two tables: by medication AND by medication type

// ------ Helpers ------
const Badge = (text, tone) =>
  <span className={"taken-badge taken-" + String(tone).toLowerCase()}>{text}</span>;

const HighBadge = () => Badge("High", "after");  // uses your red-ish style
const LowBadge  = () => Badge("Low",  "before"); // uses your blue-ish style

const mean   = a => (a && a.length ? a.reduce((x,y)=>x+y)/a.length : null);
const first  = v => Array.isArray(v) ? (v[0] ?? null) : v;
const pushN  = (arr, x) => { const n = Number(x); if (!isNaN(n)) arr.push(n); };
const pushPair = (sArr, dArr, s, d) => {
  const ns = Number(s), nd = Number(d);
  if (!isNaN(ns) && !isNaN(nd)) { sArr.push(ns); dArr.push(nd); }
};

// Convert ISO time to minutes since midnight
const isoToMinutes = (v) => {
  if (!v) return null;
  const d = v instanceof Date ? v : new Date(String(v));
  if (isNaN(d)) return null;
  return d.getHours() * 60 + d.getMinutes();
};

// Extract YYYY-MM-DD from wake_time / bedtime / title / path
const ymdFrom = (p) => {
  const isoDate = (s) => {
    if (typeof s !== "string") return null;
    const m = s.match(/^(\d{4}-\d{2}-\d{2})/);
    return m ? m[1] : null;
  };
  const fromTitle = (s) => {
    if (typeof s !== "string") return null;
    const m = s.match(/^(\d{4})[_-](\d{2})[_-](\d{2})$/);
    return m ? (m[1] + "-" + m[2] + "-" + m[3]) : null;
  };
  const fromPath = (s) => {
    if (typeof s !== "string") return null;
    const m = s.match(/(\d{4}-\d{2}-\d{2})/);
    return m ? m[1] : null;
  };
  return (
    isoDate(p.value("wake_time")) ??
    isoDate(p.value("bedtime")) ??
    fromTitle((p.file && p.file.basename) ?? p.value("title")) ??
    fromPath((p.file && p.file.path) ?? "")
  );
};

const shiftYMD = (ymd, days=-1) => {
  if (!ymd) return null;
  const d = new Date(ymd + "T00:00:00");
  if (isNaN(d)) return null;
  d.setDate(d.getDate() + days);
  return d.toISOString().slice(0,10);
};

const num = v => <span className="num">{v}</span>;
const byLabel = (a,b) => String(a.label).localeCompare(String(b.label));
const formatDate = d => d ? d.replace(/-/g, '_') : d;

// Compute per-table extremes for a metric key (e.g., "avgSys")
const extremes = (rows, key) => {
  const vals = rows.map(r => r[key]).filter(v => v != null && !isNaN(v));
  if (!vals.length) return { min: null, max: null };
  return { min: Math.min.apply(null, vals), max: Math.max.apply(null, vals) };
};

// Render value + (optional) color + badge based on min/max within this table
const cellBP = (v, min, max) => {
  if (v == null) return "—";
  const klass = (v === max) ? "bp-high" : (v === min) ? "bp-low" : "";
  const badge = (v === max) ? HighBadge() : (v === min) ? LowBadge() : null;
  return <span className="num"><span className={klass}>{Math.round(v)}</span>{badge ? <> {badge}</> : null}</span>;
};
const cellPlain = (v, min, max, digits=1) => {
  if (v == null) return "—";
  const badge = (v === max) ? HighBadge() : (v === min) ? LowBadge() : null;
  const val = (digits === 0) ? Math.round(v) : (Math.round(v * Math.pow(10,digits)) / Math.pow(10,digits)).toFixed(digits);
  return <span className="num">{val}{badge ? <> {badge}</> : null}</span>;
};

// ------ Main ------
return function View() {
  const pages = dc.useQuery("@page");

  // Map day -> med / med_type (what you used the night OF that day)
  const medByDate = {};
  const typeByDate   = {};
  for (const p of pages) {
    const d = ymdFrom(p);
    if (!d) continue;
    const s = first(p.value("med"));
    const t = p.value("med_type");
    if (s != null) medByDate[d] = s;
    if (t != null) typeByDate[d]   = t;
  }

  // Link TODAY's med to TOMORROW's sleep
  // (because today's med is taken tonight, affecting tomorrow morning's sleep)
  // We need to look ahead: for each page, get the NEXT day's sleep
  const bucketsByMed = {};   // key -> {sleep[], qty[], sys[], dia[], steps[]}
  const bucketsByType   = {};
  const ensure = (m, k) => (m[k] || (m[k] = { nights: 0, sleep:[], qty:[], sys:[], dia:[], steps:[] }), m[k]);

  // Build a map of date -> page data for quick lookup
  const pageByDate = {};
  for (const p of pages) {
    const d = ymdFrom(p);
    if (d) pageByDate[d] = p;
  }

  for (const p of pages) {
    const today = ymdFrom(p);
    if (!today) continue;

    const sKey = medByDate[today];
    const tKey = typeByDate[today];

    // Only process if this day has a med
    if (!sKey && !tKey) continue;

    // Get TOMORROW's data (the morning after taking tonight's med)
    const tmrw = shiftYMD(today, +1);
    const nextPage = tmrw ? pageByDate[tmrw] : null;
    if (!nextPage) continue;

    // Sleep and steps from tomorrow (effects the next day)
    const sleep = nextPage.value("sleep") ?? nextPage.value("sleep_mins");
    const steps = nextPage.value("steps");

    // Qty from TODAY (usage on the same night as the med)
    const qty = p.value("qty");

    // BP: Use TODAY's Sleep (around dose time) + TOMORROW's Wake (morning after)
    const sysSleep_today = p.value("pm_sys");
    const diaSleep_today = p.value("pm_dia");
    const sysWake_tmrw = nextPage.value("am_sys");
    const diaWake_tmrw = nextPage.value("am_dia");

    const addToBucket = (B) => {
      B.nights += 1;
      pushN(B.sleep, sleep);
      pushN(B.qty,  qty);
      pushN(B.steps, steps);
      // Only count BP readings when BOTH sys & dia exist for that reading
      pushPair(B.sys, B.dia, sysSleep_today, diaSleep_today);  // Tonight's Sleep BP
      pushPair(B.sys, B.dia, sysWake_tmrw, diaWake_tmrw);    // Tomorrow's Wake BP
    };

    if (sKey) addToBucket(ensure(bucketsByMed, sKey));
    if (tKey) addToBucket(ensure(bucketsByType,   tKey));
  }

  // Build data rows
  const rowsFrom = (buckets) => {
    const rows = [];
    for (const k in buckets) {
      const g = buckets[k];
      rows.push({
        label   : k,
        avgSleep: mean(g.sleep),
        avgQty  : mean(g.qty),
        avgSys  : mean(g.sys),
        avgDia  : mean(g.dia),
        avgSteps: mean(g.steps),
        nights  : g.nights,
        bpReads : Math.min(g.sys.length, g.dia.length),
      });
    }
    rows.sort((a,b) =>
      ((b.avgSleep ?? -1) - (a.avgSleep ?? -1)) || byLabel(a,b)
    );
    return rows;
  };

  const rowsByMed = rowsFrom(bucketsByMed);
  const rowsByType   = rowsFrom(bucketsByType);

  // Compute extremes per table (used for badges and coloring)
  const Sx = {
    sleep: extremes(rowsByMed, "avgSleep"),
    qty  : extremes(rowsByMed, "avgQty"),
    sys  : extremes(rowsByMed, "avgSys"),
    dia  : extremes(rowsByMed, "avgDia"),
    steps: extremes(rowsByMed, "avgSteps"),
  };
  const Tx = {
    sleep: extremes(rowsByType, "avgSleep"),
    qty  : extremes(rowsByType, "avgQty"),
    sys  : extremes(rowsByType, "avgSys"),
    dia  : extremes(rowsByType, "avgDia"),
    steps: extremes(rowsByType, "avgSteps"),
  };

  // Columns (by MEDICATION) — BP cells colored + all metrics get High/Low badges
  const COLS_MED = [
    { id: "Label",         value: r => r.label },
    { id: "Avg Sleep",     value: r => cellPlain(r.avgSleep, Sx.sleep.min, Sx.sleep.max, 1) },
    { id: "Avg Qty",       value: r => cellPlain(r.avgQty,   Sx.qty.min,   Sx.qty.max,   1) },
    { id: "Avg Systolic",  value: r => cellBP   (r.avgSys,   Sx.sys.min,   Sx.sys.max)      },
    { id: "Avg Diastolic", value: r => cellBP   (r.avgDia,   Sx.dia.min,   Sx.dia.max)      },
    { id: "Avg Steps",     value: r => cellPlain(r.avgSteps, Sx.steps.min, Sx.steps.max, 0) },
    { id: "Nights",        value: r => num(r.nights) },
    { id: "BP Reads",      value: r => num(r.bpReads) },
  ];

  // Columns (by MEDICATION TYPE)
  const COLS_TYPE = [
    { id: "Label",         value: r => r.label },
    { id: "Avg Sleep",     value: r => cellPlain(r.avgSleep, Tx.sleep.min, Tx.sleep.max, 1) },
    { id: "Avg Qty",       value: r => cellPlain(r.avgQty,   Tx.qty.min,   Tx.qty.max,   1) },
    { id: "Avg Systolic",  value: r => cellBP   (r.avgSys,   Tx.sys.min,   Tx.sys.max)      },
    { id: "Avg Diastolic", value: r => cellBP   (r.avgDia,   Tx.dia.min,   Tx.dia.max)      },
    { id: "Avg Steps",     value: r => cellPlain(r.avgSteps, Tx.steps.min, Tx.steps.max, 0) },
    { id: "Nights",        value: r => num(r.nights) },
    { id: "BP Reads",      value: r => num(r.bpReads) },
  ];

  // ===== SLEEP EFFICIENCY TABLE =====
  // Calculate sleep efficiency: (sleep duration / time in bed) * 100
  const sleepEffData = [];
  for (const p of pages) {
    const d = ymdFrom(p);
    if (!d) continue;

    const bedtime = isoToMinutes(p.value("bedtime"));
    const wakeTime = isoToMinutes(p.value("wake_time"));
    const sleepMins = first(p.value("sleep") ?? p.value("sleep_mins"));

    if (bedtime != null && wakeTime != null && sleepMins != null) {
      const timeInBed = wakeTime >= bedtime ? wakeTime - bedtime : (wakeTime + 24 * 60 - bedtime);
      const efficiency = timeInBed > 0 ? (sleepMins / timeInBed) * 100 : null;

      if (efficiency != null) {
        sleepEffData.push({
          date: d,
          sleepMins: sleepMins,
          timeInBed: timeInBed,
          efficiency: efficiency
        });
      }
    }
  }

  // Sort by date descending and take last 30
  sleepEffData.sort((a, b) => b.date.localeCompare(a.date));
  const recentSleepEff = sleepEffData.slice(0, 30);

  const avgEfficiency = mean(recentSleepEff.map(d => d.efficiency));
  const minEffDate = recentSleepEff.reduce((min, d) => d.efficiency < min.efficiency ? d : min, recentSleepEff[0] || {});
  const maxEffDate = recentSleepEff.reduce((max, d) => d.efficiency > max.efficiency ? d : max, recentSleepEff[0] || {});

  const efficiency_rows = [{
    metric: "Sleep Efficiency (last 30 days)",
    avg: avgEfficiency,
    min: minEffDate.efficiency,
    min_date: minEffDate.date,
    max: maxEffDate.efficiency,
    max_date: maxEffDate.date,
    status: avgEfficiency >= 85 ? "✓ Good" : avgEfficiency >= 75 ? "⚠️ Fair" : "⚠️ Poor"
  }];

  const efficiency_cols = [
    { id: "metric", title: "Metric", value: r => r.metric },
    { id: "avg", title: "Average Efficiency", value: r => r.avg != null ? <span className="num">{r.avg.toFixed(1)}%</span> : "—" },
    { id: "min", title: "Min", value: r => r.min != null ? <span className="num">{r.min.toFixed(1)}%</span> : "—" },
    { id: "min_date", title: "Date", value: r => formatDate(r.min_date) || "—" },
    { id: "max", title: "Max", value: r => r.max != null ? <span className="num">{r.max.toFixed(1)}%</span> : "—" },
    { id: "max_date", title: "Date", value: r => formatDate(r.max_date) || "—" },
    { id: "status", title: "Status", value: r => r.status }
  ];

  return (
    <div>
      <h3>By Medication (yesterday's medication → today's sleep)</h3>
      <dc.Table columns={COLS_MED} rows={rowsByMed} />

      <h3>By Medication Type (yesterday's type → today's sleep)</h3>
      <dc.Table columns={COLS_TYPE} rows={rowsByType} />

      <h3>Sleep Efficiency Analysis</h3>
      <dc.Table columns={efficiency_cols} rows={efficiency_rows} />
    </div>
  );
}
```
