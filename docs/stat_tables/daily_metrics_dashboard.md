---
age:
  - 38.1.7
age_unix: 1202577889
authors:
  - jwl
title: daily_metrics_dashboard
timestamp: 1759890596100
date_created: 2025-10-07T22:13:26
date_updated: 2025-10-21T10:16:53
hash: ea7bce2ba12935d5ffcd36d7169827f1d3281f2fe060e98687e3e0761d78ce50
id: a2ff8cfb-6836-4f90-9f8a-78532eeba3b5
tags:
  - dashboard
  - datacore
  - metrics
---

# daily_metrics_dashboard

## What this dashboard shows

### Purpose

This dashboard provides a comprehensive daily snapshot of key health metrics related to blood pressure, medication timing, physical activity, weight, and sleep. By tracking and visualizing these metrics together, it aims to:
- Monitor overall health status and trends over time
- Identify potential correlations between different health factors
- Help guide lifestyle and treatment decisions to optimize wellbeing

### Metrics Tracked

- **Blood Pressure:** Morning (Wake) and evening (Sleep) readings for systolic, diastolic, mean arterial pressure, and pulse.
- **Medication Timing:** Timestamps for morning and evening medication doses.
- **General Health:** Daily weight, step counts, and weight change rate (lbs/week).
- **Sleep:** Bedtime, wake time, time in bed, and sleep duration (from both manual logs and sleep tracker data).

### Methodology

- Blood pressure metrics include lowest and highest single readings, the dates they occurred, and whether the reading was before or after scheduled medication doses. Averages and deviations summarize the overall distribution.
- Medication timing shows the earliest and latest timestamps logged, along with the average dosing time.
- Weight and steps compare minimum, maximum, and average values.
- **Weight Change Rate** shows rate of weight loss/gain in pounds per week across three time periods:
  - **7-Day Rate**: Recent short-term trend (last 7 days)
  - **30-Day Rate**: Medium-term trend (last 30 days)
  - **All-Time Rate**: Overall trend since first weight entry
  - Also shows total weight change since starting tracking
- Sleep metrics highlight the earliest and latest bedtimes and wake times, along with average time in bed and sleep duration. Sleep tracker data is summarized separately.

### How to Interpret

- The "Lowest" and "Highest" columns identify extreme single values and when they occurred. "Low" values are colored blue while "High" values are red.
- "Average" and "Deviation" provide measures of central tendency and variability for each metric over the selected date range.
- Bedtime and Wake Time are given in 24-hour (military) format, while Sleep and Time in Bed duration are shown in hours and minutes.
- Medication Timing shows the actual earliest, latest, and average timestamps for each dosing schedule.
- "Taken" indicates whether the paired blood pressure reading occurred before or after that dose. Blanks indicate no medication time was logged.

Use this dashboard to track stability and changes in key metrics over time. Evaluate if medication timing affects blood pressure control, how activity and weight relate to each other and to sleep, and whether sleep quality remains consistent. Bring any notable patterns to your doctor to inform your care plan.

```datacorejsx
// === Daily Metrics Dashboard (Three Tables with Deviation) ===

const TAG_FILTER = "med-note";  // set to null to include all notes
const DAYS_WINDOW = null;            // e.g., 90 for last 90 days; null = all-time

// ---- Column Definitions ----
const BP_COLUMNS = [
  { id: "metric", title: "Metric", value: r => r.metric },
  { id: "lowest", title: "Lowest", value: r => r.lowest },
  { id: "low_date", title: "Date", value: r => formatDate(r.low_date) },
  { id: "low_taken", title: "Taken", value: r => r.low_taken },
  { id: "highest", title: "Highest", value: r => r.highest },
  { id: "high_date", title: "Date", value: r => formatDate(r.high_date) },
  { id: "high_taken", title: "Taken", value: r => r.high_taken },
  { id: "average", title: "Average", value: r => r.average },
  { id: "deviation", title: "Deviation", value: r => r.deviation }
];

const HEALTH_COLUMNS = [
  { id: "metric", title: "Metric", value: r => r.metric },
  { id: "lowest", title: "Lowest", value: r => r.lowest },
  { id: "low_date", title: "Date", value: r => formatDate(r.low_date) },
  { id: "highest", title: "Highest", value: r => r.highest },
  { id: "high_date", title: "Date", value: r => formatDate(r.high_date) },
  { id: "average", title: "Average", value: r => r.average },
  { id: "deviation", title: "Deviation", value: r => r.deviation }
];

const SLEEP_TIME_COLUMNS = [
  { id: "metric", title: "Metric", value: r => r.metric },
  { id: "earliest", title: "Earliest", value: r => r.earliest },
  { id: "early_date", title: "Date", value: r => formatDate(r.early_date) },
  { id: "latest", title: "Latest", value: r => r.latest },
  { id: "late_date", title: "Date", value: r => formatDate(r.late_date) },
  { id: "average", title: "Average", value: r => r.average },
  { id: "deviation", title: "Deviation", value: r => r.deviation }
];

const SLEEP_DURATION_COLUMNS = [
  { id: "metric", title: "Metric", value: r => r.metric },
  { id: "earliest", title: "Shortest", value: r => r.earliest },
  { id: "early_date", title: "Date", value: r => formatDate(r.early_date) },
  { id: "latest", title: "Longest", value: r => r.latest },
  { id: "late_date", title: "Date", value: r => formatDate(r.late_date) },
  { id: "average", title: "Average", value: r => r.average },
  { id: "deviation", title: "Deviation", value: r => r.deviation }
];

const SLEEP_GAP_COLUMNS = [
  { id: "date", title: "Date", value: r => formatDate(r.date) },
  { id: "aid", title: "Aid", value: r => r.aid },
  { id: "dose", title: "Dose", value: r => r.dose ?? "—" },
  { id: "time", title: "Time", value: r => r.time ?? "—" },
];


// ---- Helpers ----
const toNumber = (v) => {
  if (v == null) return null;
  if (typeof v === "number") return Number.isFinite(v) ? v : null;
  const n = Number(String(v).trim().replace(/,/g, ""));
  return Number.isFinite(n) ? n : null;
};

const isoToMinutes = (v) => {
  if (!v) return null;
  const d = v instanceof Date ? v : new Date(String(v));
  if (isNaN(d)) return null;
  return d.getHours() * 60 + d.getMinutes();
};

const minutesToHHMM = (m) => {
  if (m == null || !Number.isFinite(m)) return "—";
  m = Math.round(m);
  const hh = Math.floor(m / 60) % 24;
  const mm = m % 60;
  return `${String(hh).padStart(2, "0")}:${String(mm).padStart(2, "0")}`;
};

const minutesToDuration = (m) => {
  if (m == null || !Number.isFinite(m)) return "—";
  m = Math.round(m);
  const hours = Math.floor(m / 60);
  const mins = m % 60;
  return `${hours} hours ${mins} minutes`;
};

const formatDate = d => d ? d.replace(/-/g, '_') : d;

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

const pageEpochMs = (p) => {
  const fm = p.value && p.value("date_created");
  if (fm) {
    const d = new Date(String(fm).replace(/T(\d{2})-(\d{2})-(\d{2})/, "T$1:$2:$3"));
    if (!isNaN(d)) return d.getTime();
  }
  if (p.$ctime) {
    const d = new Date(p.$ctime);
    if (!isNaN(d)) return d.getTime();
  }
  return null;
};

const Badge = (text, tone) =>
  <span className={"taken-badge taken-" + String(tone).toLowerCase()}>{text}</span>;

const HighBadge = () => Badge("High", "after");  // red-ish style
const LowBadge = () => Badge("Low", "before");   // blue-ish style

const colorValue = (val, isHigh) => (
  <>
    <span className={isHigh ? "bp-high" : "bp-low"}>{val}</span>
    {isHigh ? <> <HighBadge /></> : <> <LowBadge /></>}
  </>
);

const toTitleCase = (str) => {
  return str.split('_').map(word =>
    word.charAt(0).toUpperCase() + word.slice(1)
  ).join(' ');
};

// Calculate Mean Arterial Pressure
const calcMAP = (sys, dia) => {
  if (sys == null || dia == null) return null;
  return dia + (sys - dia) / 3;
};

// Calculate standard deviation
const calcStdDev = (values, mean) => {
  if (values.length < 2) return null;
  const squaredDiffs = values.map(v => Math.pow(v - mean, 2));
  const variance = squaredDiffs.reduce((a, b) => a + b, 0) / values.length;
  return Math.sqrt(variance);
};

// === NEW: Pre-split Wake => "Before" logic baked in ===
const SPLIT_START = new Date("2025-10-12T00:00:00");

// Check if BP was taken before or after meds
const checkMedTiming = (page, bpTimeField, medsTimeField) => {
  const bpTime = isoToMinutes(page.value ? page.value(bpTimeField) : undefined);
  const medsTime = isoToMinutes(page.value ? page.value(medsTimeField) : undefined);

  const splitStart = new Date("2025-10-12T00:00:00");
  const createdMs = pageEpochMs(page);
  const createdAt = createdMs != null ? new Date(createdMs) : null;

  // Pre-split Wake readings = AFTER meds in your routine
  if (createdAt && createdAt < splitStart && /am_bp/i.test(bpTimeField)) {
    return "After";
  }

  if (bpTime == null || medsTime == null) return "—";
  return bpTime > medsTime ? "After" : "Before";
};

return function View() {
  // IMPORTANT: pages is scoped here; nothing touches it at top-level.
  let pages = dc.useQuery("@page");

  if (TAG_FILTER) {
    pages = pages.filter(p => {
      const t = p.value && p.value("tags");
      if (!t) return false;
      if (Array.isArray(t)) return t.includes(TAG_FILTER);
      return String(t).split(/[\,\s]+/).includes(TAG_FILTER);
    });
  }

  // Exclude template folder
  pages = pages.filter(p => {
    const path = p.$path || "";
    return !path.startsWith("templates/");
  });

  if (DAYS_WINDOW && Number.isFinite(DAYS_WINDOW)) {
    const cutoff = Date.now() - DAYS_WINDOW * 24 * 60 * 60 * 1000;
    pages = pages.filter(p => {
      const ms = pageEpochMs(p);
      return ms == null ? true : ms >= cutoff;
    });
  }

  // ===== BLOOD PRESSURE & MEDICATION METRICS =====
  const bpRows = [];

  // Collect Wake BP data
  const bpWakeData = [];
  for (const p of pages) {
    const sys = toNumber(p.value ? p.value("am_sys") : undefined);
    const dia = toNumber(p.value ? p.value("am_dia") : undefined);
    if (sys != null && dia != null) {
      bpWakeData.push({ sys, dia, map: calcMAP(sys, dia), page: p });
    }
  }

  // Collect Sleep BP data
  const bpSleepData = [];
  for (const p of pages) {
    const sys = toNumber(p.value ? p.value("pm_sys") : undefined);
    const dia = toNumber(p.value ? p.value("pm_dia") : undefined);
    if (sys != null && dia != null) {
      bpSleepData.push({ sys, dia, map: calcMAP(sys, dia), page: p });
    }
  }

  // Systolic Wake row
  if (bpWakeData.length > 0) {
    let minSys = bpWakeData[0], maxSys = bpWakeData[0];
    let sumSys = 0, sumDia = 0;
    const sysValues = [];

    for (const item of bpWakeData) {
      if (item.sys < minSys.sys) minSys = item;
      if (item.sys > maxSys.sys) maxSys = item;
      sumSys += item.sys;
      sumDia += item.dia;
      sysValues.push(item.sys);
    }

    const avgSys = sumSys / bpWakeData.length;
    const avgDia = sumDia / bpWakeData.length;
    const stdDevSys = calcStdDev(sysValues, avgSys);

    bpRows.push({
      metric: "Systolic Wake",
      lowest: <span>{colorValue(minSys.sys, false)}/{minSys.dia}</span>,
      low_date: pageDateYMD(minSys.page),
      low_taken: checkMedTiming(minSys.page, "am_bp_time", "am_meds"),
      highest: <span>{colorValue(maxSys.sys, true)}/{maxSys.dia}</span>,
      high_date: pageDateYMD(maxSys.page),
      high_taken: checkMedTiming(maxSys.page, "am_bp_time", "am_meds"),
      average: `${Math.round(avgSys)}/${Math.round(avgDia)}`,
      deviation: stdDevSys ? `±${stdDevSys.toFixed(1)}` : "—"
    });
  }

  // Systolic Sleep row
  if (bpSleepData.length > 0) {
    let minSys = bpSleepData[0], maxSys = bpSleepData[0];
    let sumSys = 0, sumDia = 0;
    const sysValues = [];

    for (const item of bpSleepData) {
      if (item.sys < minSys.sys) minSys = item;
      if (item.sys > maxSys.sys) maxSys = item;
      sumSys += item.sys;
      sumDia += item.dia;
      sysValues.push(item.sys);
    }

    const avgSys = sumSys / bpSleepData.length;
    const avgDia = sumDia / bpSleepData.length;
    const stdDevSys = calcStdDev(sysValues, avgSys);

    bpRows.push({
      metric: "Systolic Sleep",
      lowest: <span>{colorValue(minSys.sys, false)}/{minSys.dia}</span>,
      low_date: pageDateYMD(minSys.page),
      low_taken: checkMedTiming(minSys.page, "pm_bp_time", "pm_meds"),
      highest: <span>{colorValue(maxSys.sys, true)}/{maxSys.dia}</span>,
      high_date: pageDateYMD(maxSys.page),
      high_taken: checkMedTiming(maxSys.page, "pm_bp_time", "pm_meds"),
      average: `${Math.round(avgSys)}/${Math.round(avgDia)}`,
      deviation: stdDevSys ? `±${stdDevSys.toFixed(1)}` : "—"
    });
  }

  // Diastolic Wake row
  if (bpWakeData.length > 0) {
    let minDia = bpWakeData[0], maxDia = bpWakeData[0];
    let sumSys = 0, sumDia = 0;
    const diaValues = [];

    for (const item of bpWakeData) {
      if (item.dia < minDia.dia) minDia = item;
      if (item.dia > maxDia.dia) maxDia = item;
      sumSys += item.sys;
      sumDia += item.dia;
      diaValues.push(item.dia);
    }

    const avgSys = sumSys / bpWakeData.length;
    const avgDia = sumDia / bpWakeData.length;
    const stdDevDia = calcStdDev(diaValues, avgDia);

    bpRows.push({
      metric: "Diastolic Wake",
      lowest: <span>{minDia.sys}/{colorValue(minDia.dia, false)}</span>,
      low_date: pageDateYMD(minDia.page),
      low_taken: checkMedTiming(minDia.page, "am_bp_time", "am_meds"),
      highest: <span>{maxDia.sys}/{colorValue(maxDia.dia, true)}</span>,
      high_date: pageDateYMD(maxDia.page),
      high_taken: checkMedTiming(maxDia.page, "am_bp_time", "am_meds"),
      average: `${Math.round(avgSys)}/${Math.round(avgDia)}`,
      deviation: stdDevDia ? `±${stdDevDia.toFixed(1)}` : "—"
    });
  }

  // Diastolic Sleep row
  if (bpSleepData.length > 0) {
    let minDia = bpSleepData[0], maxDia = bpSleepData[0];
    let sumSys = 0, sumDia = 0;
    const diaValues = [];

    for (const item of bpSleepData) {
      if (item.dia < minDia.dia) minDia = item;
      if (item.dia > maxDia.dia) maxDia = item;
      sumSys += item.sys;
      sumDia += item.dia;
      diaValues.push(item.dia);
    }

    const avgSys = sumSys / bpSleepData.length;
    const avgDia = sumDia / bpSleepData.length;
    const stdDevDia = calcStdDev(diaValues, avgDia);

    bpRows.push({
      metric: "Diastolic Sleep",
      lowest: <span>{minDia.sys}/{colorValue(minDia.dia, false)}</span>,
      low_date: pageDateYMD(minDia.page),
      low_taken: checkMedTiming(minDia.page, "pm_bp_time", "pm_meds"),
      highest: <span>{maxDia.sys}/{colorValue(maxDia.dia, true)}</span>,
      high_date: pageDateYMD(maxDia.page),
      high_taken: checkMedTiming(maxDia.page, "pm_bp_time", "pm_meds"),
      average: `${Math.round(avgSys)}/${Math.round(avgDia)}`,
      deviation: stdDevDia ? `±${stdDevDia.toFixed(1)}` : "—"
    });
  }

  // Mean Arterial Pressure Wake row
  if (bpWakeData.length > 0) {
    let minMAP = bpWakeData[0], maxMAP = bpWakeData[0];
    let sumSys = 0, sumDia = 0;
    const mapValues = [];

    for (const item of bpWakeData) {
      if (item.map < minMAP.map) minMAP = item;
      if (item.map > maxMAP.map) maxMAP = item;
      sumSys += item.sys;
      sumDia += item.dia;
      mapValues.push(item.map);
    }

    const avgSys = sumSys / bpWakeData.length;
    const avgDia = sumDia / bpWakeData.length;
    const avgMAP = mapValues.reduce((a, b) => a + b, 0) / mapValues.length;
    const stdDevMAP = calcStdDev(mapValues, avgMAP);

    bpRows.push({
      metric: "Mean Arterial Pressure Wake",
      lowest: `${minMAP.sys}/${minMAP.dia}`,
      low_date: pageDateYMD(minMAP.page),
      low_taken: checkMedTiming(minMAP.page, "am_bp_time", "am_meds"),
      highest: `${maxMAP.sys}/${maxMAP.dia}`,
      high_date: pageDateYMD(maxMAP.page),
      high_taken: checkMedTiming(maxMAP.page, "am_bp_time", "am_meds"),
      average: `${Math.round(avgSys)}/${Math.round(avgDia)}`,
      deviation: stdDevMAP ? `±${stdDevMAP.toFixed(1)}` : "—"
    });
  }

  // Mean Arterial Pressure Sleep row
  if (bpSleepData.length > 0) {
    let minMAP = bpSleepData[0], maxMAP = bpSleepData[0];
    let sumSys = 0, sumDia = 0;
    const mapValues = [];

    for (const item of bpSleepData) {
      if (item.map < minMAP.map) minMAP = item;
      if (item.map > maxMAP.map) maxMAP = item;
      sumSys += item.sys;
      sumDia += item.dia;
      mapValues.push(item.map);
    }

    const avgSys = sumSys / bpSleepData.length;
    const avgDia = sumDia / bpSleepData.length;
    const avgMAP = mapValues.reduce((a, b) => a + b, 0) / mapValues.length;
    const stdDevMAP = calcStdDev(mapValues, avgMAP);

    bpRows.push({
      metric: "Mean Arterial Pressure Sleep",
      lowest: `${minMAP.sys}/${minMAP.dia}`,
      low_date: pageDateYMD(minMAP.page),
      low_taken: checkMedTiming(minMAP.page, "pm_bp_time", "pm_meds"),
      highest: `${maxMAP.sys}/${maxMAP.dia}`,
      high_date: pageDateYMD(maxMAP.page),
      high_taken: checkMedTiming(maxMAP.page, "pm_bp_time", "pm_meds"),
      average: `${Math.round(avgSys)}/${Math.round(avgDia)}`,
      deviation: stdDevMAP ? `±${stdDevMAP.toFixed(1)}` : "—"
    });
  }

  // Pulse Wake
  const pulseWake = [];
  for (const p of pages) {
    const val = toNumber(p.value ? p.value("am_hr") : undefined);
    if (val != null) pulseWake.push({ value: val, page: p });
  }

  if (pulseWake.length > 0) {
    let minItem = pulseWake[0], maxItem = pulseWake[0];
    let sum = 0;
    const values = [];

    for (const item of pulseWake) {
      if (item.value < minItem.value) minItem = item;
      if (item.value > maxItem.value) maxItem = item;
      sum += item.value;
      values.push(item.value);
    }

    const avg = sum / pulseWake.length;
    const stdDev = calcStdDev(values, avg);

    bpRows.push({
      metric: "Pulse Wake",
      lowest: colorValue(minItem.value, false),
      low_date: pageDateYMD(minItem.page),
      low_taken: checkMedTiming(minItem.page, "am_bp_time", "am_meds"),
      highest: colorValue(maxItem.value, true),
      high_date: pageDateYMD(maxItem.page),
      high_taken: checkMedTiming(maxItem.page, "am_bp_time", "am_meds"),
      average: avg.toFixed(2),
      deviation: stdDev ? `±${stdDev.toFixed(1)}` : "—"
    });
  }

  // Pulse Sleep
  const pulseSleep = [];
  for (const p of pages) {
    const val = toNumber(p.value ? p.value("pm_hr") : undefined);
    if (val != null) pulseSleep.push({ value: val, page: p });
  }

  if (pulseSleep.length > 0) {
    let minItem = pulseSleep[0], maxItem = pulseSleep[0];
    let sum = 0;
    const values = [];

    for (const item of pulseSleep) {
      if (item.value < minItem.value) minItem = item;
      if (item.value > maxItem.value) maxItem = item;
      sum += item.value;
      values.push(item.value);
    }

    const avg = sum / pulseSleep.length;
    const stdDev = calcStdDev(values, avg);

    bpRows.push({
      metric: "Pulse Sleep",
      lowest: colorValue(minItem.value, false),
      low_date: pageDateYMD(minItem.page),
      low_taken: checkMedTiming(minItem.page, "pm_bp_time", "pm_meds"),
      highest: colorValue(maxItem.value, true),
      high_date: pageDateYMD(maxItem.page),
      high_taken: checkMedTiming(maxItem.page, "pm_bp_time", "pm_meds"),
      average: avg.toFixed(2),
      deviation: stdDev ? `±${stdDev.toFixed(1)}` : "—"
    });
  }

  // Morning Meds Time
  const morningMeds = [];
  for (const p of pages) {
    const m = p.value ? p.value("am_meds") : undefined;
    const mm = isoToMinutes(m);
    if (mm != null) morningMeds.push({ value: mm, page: p });
  }

  if (morningMeds.length > 0) {
    let earliest = morningMeds[0], latest = morningMeds[0];
    let sum = 0;

    for (const item of morningMeds) {
      if (item.value < earliest.value) earliest = item;
      if (item.value > latest.value) latest = item;
      sum += item.value;
    }

    const avg = sum / morningMeds.length;

    bpRows.push({
      metric: "Morning Meds Time",
      lowest: minutesToHHMM(earliest.value),
      low_date: pageDateYMD(earliest.page),
      low_taken: "—",
      highest: minutesToHHMM(latest.value),
      high_date: pageDateYMD(latest.page),
      high_taken: "—",
      average: minutesToHHMM(avg),
      deviation: "—"
    });
  }

  // Night Meds Time
  const nightMeds = [];
  for (const p of pages) {
    const m = p.value ? p.value("pm_meds") : undefined;
    const mm = isoToMinutes(m);
    if (mm != null) nightMeds.push({ value: mm, page: p });
  }

  if (nightMeds.length > 0) {
    let earliest = nightMeds[0], latest = nightMeds[0];
    let sum = 0;

    for (const item of nightMeds) {
      if (item.value < earliest.value) earliest = item;
      if (item.value > latest.value) latest = item;
      sum += item.value;
    }

    const avg = sum / nightMeds.length;

    bpRows.push({
      metric: "Night Meds Time",
      lowest: minutesToHHMM(earliest.value),
      low_date: pageDateYMD(earliest.page),
      low_taken: "—",
      highest: minutesToHHMM(latest.value),
      high_date: pageDateYMD(latest.page),
      high_taken: "—",
      average: minutesToHHMM(avg),
      deviation: "—"
    });
  }

  // ===== GENERAL HEALTH METRICS =====
  const healthRows = [];

  // Weight and Steps
  const numericMetrics = ["weight", "steps"];

  for (const metricName of numericMetrics) {
    const values = [];
    for (const p of pages) {
      const val = toNumber(p.value ? p.value(metricName) : undefined);
      if (val != null) values.push({ value: val, page: p });
    }

    if (values.length > 0) {
      let minItem = values[0], maxItem = values[0];
      let sum = 0;
      const nums = [];

      for (const item of values) {
        if (item.value < minItem.value) minItem = item;
        if (item.value > maxItem.value) maxItem = item;
        sum += item.value;
        nums.push(item.value);
      }

      const avg = sum / values.length;
      const stdDev = calcStdDev(nums, avg);

      healthRows.push({
        metric: toTitleCase(metricName),
        lowest: colorValue(minItem.value, false),
        low_date: pageDateYMD(minItem.page),
        highest: colorValue(maxItem.value, true),
        high_date: pageDateYMD(maxItem.page),
        average: avg.toFixed(2),
        deviation: stdDev ? `±${stdDev.toFixed(1)}` : "—"
      });

      // Add weight change rate row after weight
      if (metricName === "weight" && values.length >= 2) {
        // Sort by epoch time
        const sortedValues = values.slice().sort((a, b) => {
          const aMs = pageEpochMs(a.page);
          const bMs = pageEpochMs(b.page);
          return aMs - bMs;
        });

        const firstWeight = sortedValues[0].value;
        const lastWeight = sortedValues[sortedValues.length - 1].value;
        const firstMs = pageEpochMs(sortedValues[0].page);
        const lastMs = pageEpochMs(sortedValues[sortedValues.length - 1].page);

        if (firstMs && lastMs) {
          const daysDiff = (lastMs - firstMs) / (24 * 60 * 60 * 1000);
          const weeksDiff = daysDiff / 7;
          const weightChange = firstWeight - lastWeight; // positive = loss
          const weeklyRate = weeksDiff > 0 ? weightChange / weeksDiff : null;

          // Calculate 7-day and 30-day rates
          const cutoff7d = Date.now() - 7 * 24 * 60 * 60 * 1000;
          const cutoff30d = Date.now() - 30 * 24 * 60 * 60 * 1000;

          const recent7d = sortedValues.filter(v => pageEpochMs(v.page) >= cutoff7d);
          const recent30d = sortedValues.filter(v => pageEpochMs(v.page) >= cutoff30d);

          let rate7d = null;
          if (recent7d.length >= 2) {
            const days = (pageEpochMs(recent7d[recent7d.length - 1].page) - pageEpochMs(recent7d[0].page)) / (24 * 60 * 60 * 1000);
            const change = recent7d[0].value - recent7d[recent7d.length - 1].value;
            rate7d = days > 0 ? (change / days) * 7 : null;
          }

          let rate30d = null;
          if (recent30d.length >= 2) {
            const days = (pageEpochMs(recent30d[recent30d.length - 1].page) - pageEpochMs(recent30d[0].page)) / (24 * 60 * 60 * 1000);
            const change = recent30d[0].value - recent30d[recent30d.length - 1].value;
            rate30d = days > 0 ? (change / days) * 7 : null;
          }

          healthRows.push({
            metric: "Weight Change Rate",
            lowest: rate7d != null ? `${rate7d.toFixed(2)} lbs/wk (7d)` : "—",
            low_date: "",
            highest: rate30d != null ? `${rate30d.toFixed(2)} lbs/wk (30d)` : "—",
            high_date: "",
            average: weeklyRate != null ? `${weeklyRate.toFixed(2)} lbs/wk (all-time)` : "—",
            deviation: weightChange != null ? `${Math.abs(weightChange).toFixed(1)} lbs total` : "—"
          });
        }
      }
    }
  }

  // ===== SLEEP METRICS =====
  const sleepTimeRows = [];
  const sleepDurationRows = [];

  // Bedtime (calculated by time awake from wake_time to bedtime)
  const bedtimes = [];
  for (const p of pages) {
    const w = p.value ? p.value("wake_time") : undefined;
    const b = p.value ? p.value("bedtime") : undefined;
    const wm = isoToMinutes(w);
    const bm = isoToMinutes(b);

    if (wm != null && bm != null) {
      // Calculate time awake (handling midnight crossover)
      const timeAwake = bm >= wm ? bm - wm : (bm + 24 * 60 - wm);
      bedtimes.push({ bedtimeValue: bm, timeAwake: timeAwake, page: p });
    }
  }

  if (bedtimes.length > 0) {
    let earliest = bedtimes[0], latest = bedtimes[0];
    let sum = 0;

    for (const item of bedtimes) {
      // Earliest = shortest time awake (went to bed soonest)
      if (item.timeAwake < earliest.timeAwake) earliest = item;
      // Latest = longest time awake (stayed up latest)
      if (item.timeAwake > latest.timeAwake) latest = item;

      // For average calculation, treat early morning times (00:00-06:00) as next day
      let bedtimeForAvg = item.bedtimeValue;
      if (bedtimeForAvg < 6 * 60) { // If between 00:00 and 06:00
        bedtimeForAvg += 24 * 60; // Add 24 hours
      }
      sum += bedtimeForAvg;
    }

    let avg = sum / bedtimes.length;
    // Convert back to 24-hour format if needed
    if (avg >= 24 * 60) {
      avg = avg - 24 * 60;
    }

    sleepTimeRows.push({
      metric: "Bedtime",
      earliest: minutesToHHMM(earliest.bedtimeValue),
      early_date: pageDateYMD(earliest.page),
      latest: minutesToHHMM(latest.bedtimeValue),
      late_date: pageDateYMD(latest.page),
      average: minutesToHHMM(avg),
      deviation: "—"
    });
  }

  // Wake Time
  const wakeTimes = [];
  for (const p of pages) {
    const w = p.value ? p.value("wake_time") : undefined;
    const wm = isoToMinutes(w);
    if (wm != null) wakeTimes.push({ value: wm, page: p });
  }

  if (wakeTimes.length > 0) {
    let earliest = wakeTimes[0], latest = wakeTimes[0];
    let sum = 0;

    for (const item of wakeTimes) {
      if (item.value < earliest.value) earliest = item;
      if (item.value > latest.value) latest = item;
      sum += item.value;
    }

    const avg = sum / wakeTimes.length;

    sleepTimeRows.push({
      metric: "Wake Time",
      earliest: minutesToHHMM(earliest.value),
      early_date: pageDateYMD(earliest.page),
      latest: minutesToHHMM(latest.value),
      late_date: pageDateYMD(latest.page),
      average: minutesToHHMM(avg),
      deviation: "—"
    });
  }

  // Sleep Duration (calculated)
  const durations = [];
  for (const p of pages) {
    const b = p.value ? p.value("bedtime") : undefined;
    const w = p.value ? p.value("wake_time") : undefined;
    const bm = isoToMinutes(b);
    const wm = isoToMinutes(w);

    if (bm != null && wm != null) {
      const span = wm >= bm ? wm - bm : (wm + 24 * 60 - bm);
      durations.push({ value: span, page: p });
    }
  }

  if (durations.length > 0) {
    let shortest = durations[0], longest = durations[0];
    let sum = 0;
    const values = [];

    for (const item of durations) {
      if (item.value < shortest.value) shortest = item;
      if (item.value > longest.value) longest = item;
      sum += item.value;
      values.push(item.value);
    }

    const avg = sum / durations.length;
    const stdDev = calcStdDev(values, avg);

    sleepDurationRows.push({
      metric: "Sleep Duration",
      earliest: minutesToDuration(shortest.value),
      early_date: pageDateYMD(shortest.page),
      latest: minutesToDuration(longest.value),
      late_date: pageDateYMD(longest.page),
      average: minutesToDuration(avg),
      deviation: stdDev ? `±${(stdDev / 60).toFixed(1)} hours` : "—"
    });
  }

  // Sleep (from tracker)
  const sleepTracker = [];
  for (const p of pages) {
    const val = toNumber(p.value ? p.value("sleep") : undefined);
    if (val != null) sleepTracker.push({ value: val, page: p });
  }

  if (sleepTracker.length > 0) {
    let shortest = sleepTracker[0], longest = sleepTracker[0];
    let sum = 0;
    const values = [];

    for (const item of sleepTracker) {
      if (item.value < shortest.value) shortest = item;
      if (item.value > longest.value) longest = item;
      sum += item.value;
      values.push(item.value);
    }

    const avg = sum / sleepTracker.length;
    const stdDev = calcStdDev(values, avg);

    sleepDurationRows.push({
      metric: "Sleep (Tracker)",
      earliest: minutesToDuration(shortest.value),
      early_date: pageDateYMD(shortest.page),
      latest: minutesToDuration(longest.value),
      late_date: pageDateYMD(longest.page),
      average: minutesToDuration(avg),
      deviation: stdDev ? "±" + (stdDev / 60).toFixed(1) + " hours" : "—"
    });
  }

  const getSleepAidInfo = (p) => {
    const v = (k) => (p.value ? p.value(k) : undefined);

    // Explicit fields first (if you add them later these will "just work")
    const explicitAid = v("sleep_aid") ?? v("sleep_aid_name");
    const explicitDose = v("sleep_aid_dose") ?? v("trazodone_mg");
    const nightTime = v("pm_meds") ?? v("bedtime");

    if (explicitAid) {
      const doseStr = explicitDose != null
        ? (toNumber(explicitDose) != null ? `${toNumber(explicitDose)} mg` : String(explicitDose))
        : null;
      return {
        aid: String(explicitAid),
        dose: doseStr ?? extractMg(explicitAid),
        time: minutesToHHMM(isoToMinutes(nightTime)),
      };
    }

    // Common lists where you might store meds
    const candidates = [
      ...asArray(v("night_meds")),
      ...asArray(v("meds_night")),
      ...asArray(v("medications")),
      ...asArray(v("meds")),
    ];

    if (candidates.length) {
      const traz = candidates.find(s => /trazodone/i.test(s));
      const pick = traz ?? candidates[0];
      return {
        aid: pick,
        dose: extractMg(pick),
        time: minutesToHHMM(isoToMinutes(v("pm_meds"))),
      };
    }

    // Fallback if you only log a boolean like `medication: true`
    if (v("medication") === true) {
      return {
        aid: "Medication (unspecified)",
        dose: null,
        time: minutesToHHMM(isoToMinutes(v("pm_meds"))),
      };
    }

    return { aid: "—", dose: null, time: "—" };
  };

  // === Sleep Tracker Gaps (since 2025-08-11) ===
  const GAP_START = new Date("2025-08-11T00:00:00");
  const todayYMD = new Date().toISOString().slice(0, 10); // skip current day
  const gapByDate = new Map(); // date -> { aid, dose, time }

  const sleepGapRows = Array.from(gapByDate.entries())
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([date, { aid, dose, time }]) => ({ date, aid, dose, time }));


  const extractMg = (s) => {
    if (!s) return null;
    const m = String(s).match(/(\d+(?:\.\d+)?)\s*mg/i);
    return m ? `${m[1]} mg` : null;
  };

  const asArray = (v) => {
    if (Array.isArray(v)) return v;
    if (v == null) return [];
    // split on commas or pipes; trim
    return String(v).split(/[,\|]/).map(s => s.trim()).filter(Boolean);
  };

  for (const p of pages) {
    const createdMs = pageEpochMs(p);
    if (createdMs == null) continue;
    const createdAt = new Date(createdMs);
    if (createdAt < GAP_START) continue;

    const dateYMD = pageDateYMD(p);
    if (dateYMD === todayYMD) continue;

    const sleepVal = toNumber(p.value ? p.value("sleep") : undefined);
    const isMissing = !(Number.isFinite(sleepVal) && sleepVal > 0);
    if (!isMissing) continue;

    const info = getSleepAidInfo(p);

    // Prefer explicit aid over fallback if multiple pages somehow exist for one date
    if (!gapByDate.has(dateYMD)) {
      gapByDate.set(dateYMD, info);
    } else {
      const existing = gapByDate.get(dateYMD);
      const isBetter = (existing.aid === "—" || /Medication \(unspecified\)/.test(existing.aid)) &&
        info.aid && info.aid !== "—";
      if (isBetter) gapByDate.set(dateYMD, info);
    }
  }

  return (
    <div>
      <h3>Blood Pressure & Medication Metrics</h3>
      <dc.Table columns={BP_COLUMNS} rows={bpRows} />

      <h3>General Health Metrics</h3>
      <dc.Table columns={HEALTH_COLUMNS} rows={healthRows} />

      <h3>Sleep Times</h3>
      <dc.Table columns={SLEEP_TIME_COLUMNS} rows={sleepTimeRows} />

      <h3>Sleep Duration</h3>
      <dc.Table columns={SLEEP_DURATION_COLUMNS} rows={sleepDurationRows} />

      {sleepGapRows.length > 0 && (
        <>
          <h3>Sleep Tracker Gaps (since 2025-08-11)</h3>
          <dc.Table columns={SLEEP_GAP_COLUMNS} rows={sleepGapRows} />
        </>
      )}
    </div>
  );

}
```
