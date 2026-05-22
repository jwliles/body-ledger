---
age:
  - 38.1.17
age_unix: 1203432290
authors:
  - jwl
title: correlations_dashboard
timestamp: 1760668927580
date_created: 2025-10-21T17:00:00
date_updated: 2025-10-21T17:00:00
hash: 1a3f54aebe52190a76298b11660121aa066c024d1ddc0da06c617bcbd1639708
id: 8dd15a30-6266-4c09-a1b5-f09304a9616b
tags:
  - dashboard
  - correlations
  - analytics
---

# correlations_dashboard

## What this dashboard shows

### Purpose

This dashboard analyzes **relationships between different health metrics** to help you understand:
- Does better sleep lead to lower blood pressure?
- How does activity level affect weight loss?
- Do medication timing changes correlate with BP control?
- What patterns exist between your tracked metrics?

### Metrics Analyzed

1. **Sleep vs Blood Pressure**: Does sleep duration correlate with next-day BP?
2. **Steps vs Weight**: Is increased activity linked to weight loss?
3. **Sleep vs Steps**: Does better sleep lead to more activity?
4. **Medication Timing Consistency vs BP Control**: Does taking meds at consistent times improve BP?
5. **Weight vs Blood Pressure**: How does weight loss affect BP readings?

### How to Interpret

- **Correlation Coefficient**: Ranges from -1 to +1
  - **+1.0**: Perfect positive correlation (both increase together)
  - **0.0**: No correlation
  - **-1.0**: Perfect negative correlation (one increases, other decreases)
- **Strength**:
  - **0.0-0.3**: Weak correlation
  - **0.3-0.7**: Moderate correlation
  - **0.7-1.0**: Strong correlation
- **Statistical Note**: Correlation does not equal causation. These are patterns to discuss with your doctor.

```datacorejsx
const TAG_FILTER = "med-note";
const EXCLUDE_PREFIX = "templates/";

// ===== HELPER FUNCTIONS =====
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

const pageDateYMD = (p) => {
  try {
    const name = p.$name || "";
    const dateMatch = name.match(/(\d{4})_(\d{2})_(\d{2})/);
    if (dateMatch) {
      return `${dateMatch[1]}-${dateMatch[2]}-${dateMatch[3]}`;
    }
    const title = p.value && p.value("title");
    if (title) {
      const titleMatch = String(title).match(/(\d{4})_(\d{2})_(\d{2})/);
      if (titleMatch) {
        return `${titleMatch[1]}-${titleMatch[2]}-${titleMatch[3]}`;
      }
    }
    const fm = p.value && p.value("date_created");
    if (fm) {
      const d = new Date(String(fm).replace(/T(\d{2})-(\d{2})-(\d{2})/, "T$1:$2:$3"));
      if (!isNaN(d)) return d.toISOString().slice(0, 10);
    }
    if (p.$ctime) {
      const d = new Date(p.$ctime);
      if (!isNaN(d)) return d.toISOString().slice(0, 10);
    }
  } catch {}
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

const mean = arr => {
  const valid = arr.filter(v => v != null && !isNaN(v));
  return valid.length ? valid.reduce((a,b) => a + b, 0) / valid.length : null;
};

// Calculate Pearson correlation coefficient
const correlation = (xArr, yArr) => {
  const pairs = [];
  for (let i = 0; i < Math.min(xArr.length, yArr.length); i++) {
    if (xArr[i] != null && yArr[i] != null && !isNaN(xArr[i]) && !isNaN(yArr[i])) {
      pairs.push({ x: xArr[i], y: yArr[i] });
    }
  }

  if (pairs.length < 3) return null; // Need at least 3 pairs

  const n = pairs.length;
  const sumX = pairs.reduce((s, p) => s + p.x, 0);
  const sumY = pairs.reduce((s, p) => s + p.y, 0);
  const sumXY = pairs.reduce((s, p) => s + p.x * p.y, 0);
  const sumX2 = pairs.reduce((s, p) => s + p.x * p.x, 0);
  const sumY2 = pairs.reduce((s, p) => s + p.y * p.y, 0);

  const numerator = (n * sumXY) - (sumX * sumY);
  const denominator = Math.sqrt(((n * sumX2) - (sumX * sumX)) * ((n * sumY2) - (sumY * sumY)));

  if (denominator === 0) return null;

  return numerator / denominator;
};

const strengthLabel = (r) => {
  if (r == null) return "—";
  const abs = Math.abs(r);
  if (abs < 0.3) return "Weak";
  if (abs < 0.7) return "Moderate";
  return "Strong";
};

const directionLabel = (r) => {
  if (r == null) return "—";
  if (r > 0.1) return "Positive";
  if (r < -0.1) return "Negative";
  return "None";
};

const num = (v, decimals = 2) => {
  if (v == null || isNaN(v)) return "—";
  return <span className="num">{v.toFixed(decimals)}</span>;
};

return function View() {
  let pages = dc.useQuery("@page");

  if (TAG_FILTER) {
    pages = pages.filter(p => {
      const t = p.value && p.value("tags");
      if (!t) return false;
      if (Array.isArray(t)) return t.includes(TAG_FILTER);
      return String(t).split(/[\,\s]+/).includes(TAG_FILTER);
    });
  }

  pages = pages.filter(p => !((p.$path || "").startsWith(EXCLUDE_PREFIX)));

  // Sort pages by date
  const pagesWithDates = pages.map(p => ({
    page: p,
    date: pageDateYMD(p),
    epochMs: pageEpochMs(p)
  })).filter(pd => pd.epochMs != null).sort((a, b) => a.epochMs - b.epochMs);

  // ===== CORRELATION 1: Sleep vs Next-Day BP =====
  // Does sleep duration predict next morning's blood pressure?
  const sleepToBP = [];
  for (let i = 0; i < pagesWithDates.length - 1; i++) {
    const today = pagesWithDates[i];
    const tomorrow = pagesWithDates[i + 1];

    const sleep = toNumber(today.page.value && today.page.value("sleep"));
    const nextWakeSys = toNumber(tomorrow.page.value && tomorrow.page.value("am_sys"));
    const nextWakeDia = toNumber(tomorrow.page.value && tomorrow.page.value("am_dia"));

    if (sleep != null && nextWakeSys != null && nextWakeDia != null) {
      sleepToBP.push({
        sleep: sleep,
        sys: nextWakeSys,
        dia: nextWakeDia
      });
    }
  }

  const sleepVsSys = correlation(sleepToBP.map(d => d.sleep), sleepToBP.map(d => d.sys));
  const sleepVsDia = correlation(sleepToBP.map(d => d.sleep), sleepToBP.map(d => d.dia));

  // ===== CORRELATION 2: Steps vs Weight Change =====
  const stepsToWeight = pagesWithDates.map(pd => ({
    steps: toNumber(pd.page.value && pd.page.value("steps")),
    weight: toNumber(pd.page.value && pd.page.value("weight"))
  })).filter(d => d.steps != null && d.weight != null);

  const stepsVsWeight = correlation(
    stepsToWeight.map(d => d.steps),
    stepsToWeight.map(d => d.weight)
  );

  // ===== CORRELATION 3: Sleep vs Steps (Same Day) =====
  const sleepToSteps = pagesWithDates.map(pd => ({
    sleep: toNumber(pd.page.value && pd.page.value("sleep")),
    steps: toNumber(pd.page.value && pd.page.value("steps"))
  })).filter(d => d.sleep != null && d.steps != null);

  const sleepVsSteps = correlation(
    sleepToSteps.map(d => d.sleep),
    sleepToSteps.map(d => d.steps)
  );

  // ===== CORRELATION 4: Medication Timing Variability vs BP Control =====
  // Calculate 7-day rolling windows of med timing SD and BP SD
  const windowSize = 7;
  const windows = [];

  for (let i = windowSize - 1; i < pagesWithDates.length; i++) {
    const windowPages = pagesWithDates.slice(i - windowSize + 1, i + 1);

    const amMedTimes = windowPages.map(pd => isoToMinutes(pd.page.value && pd.page.value("am_meds")))
      .filter(v => v != null);

    const bpSys = windowPages.flatMap(pd => [
      toNumber(pd.page.value && pd.page.value("am_sys")),
      toNumber(pd.page.value && pd.page.value("pm_sys"))
    ]).filter(v => v != null);

    if (amMedTimes.length >= 3 && bpSys.length >= 3) {
      const avgTime = mean(amMedTimes);
      const avgBP = mean(bpSys);

      const timeVariance = amMedTimes.reduce((sum, t) => sum + Math.pow(t - avgTime, 2), 0) / amMedTimes.length;
      const bpVariance = bpSys.reduce((sum, bp) => sum + Math.pow(bp - avgBP, 2), 0) / bpSys.length;

      const timeSD = Math.sqrt(timeVariance);
      const bpSD = Math.sqrt(bpVariance);

      windows.push({ timeSD: timeSD, bpSD: bpSD });
    }
  }

  const medTimingVsBPControl = correlation(
    windows.map(w => w.timeSD),
    windows.map(w => w.bpSD)
  );

  // ===== CORRELATION 5: Weight vs Average BP =====
  const weightToBP = pagesWithDates.map(pd => {
    const weight = toNumber(pd.page.value && pd.page.value("weight"));
    const amSys = toNumber(pd.page.value && pd.page.value("am_sys"));
    const pmSys = toNumber(pd.page.value && pd.page.value("pm_sys"));
    const avgSys = mean([amSys, pmSys]);

    return { weight: weight, sys: avgSys };
  }).filter(d => d.weight != null && d.sys != null);

  const weightVsBP = correlation(
    weightToBP.map(d => d.weight),
    weightToBP.map(d => d.sys)
  );

  // ===== BUILD CORRELATION TABLE =====
  const correlationRows = [
    {
      relationship: "Sleep Duration → Next-Day Systolic BP",
      coefficient: sleepVsSys,
      strength: strengthLabel(sleepVsSys),
      direction: directionLabel(sleepVsSys),
      interpretation: sleepVsSys && sleepVsSys < -0.3 ?
        "More sleep → Lower BP (Good!)" :
        sleepVsSys && sleepVsSys > 0.3 ?
        "More sleep → Higher BP (Review with doctor)" :
        "No strong pattern detected",
      n: sleepToBP.length
    },
    {
      relationship: "Sleep Duration → Next-Day Diastolic BP",
      coefficient: sleepVsDia,
      strength: strengthLabel(sleepVsDia),
      direction: directionLabel(sleepVsDia),
      interpretation: sleepVsDia && sleepVsDia < -0.3 ?
        "More sleep → Lower BP (Good!)" :
        sleepVsDia && sleepVsDia > 0.3 ?
        "More sleep → Higher BP (Review with doctor)" :
        "No strong pattern detected",
      n: sleepToBP.length
    },
    {
      relationship: "Daily Steps ↔ Weight",
      coefficient: stepsVsWeight,
      strength: strengthLabel(stepsVsWeight),
      direction: directionLabel(stepsVsWeight),
      interpretation: stepsVsWeight && stepsVsWeight < -0.3 ?
        "More steps → Lower weight (Good!)" :
        stepsVsWeight && stepsVsWeight > 0.3 ?
        "More steps → Higher weight (Unexpected)" :
        "No strong pattern detected",
      n: stepsToWeight.length
    },
    {
      relationship: "Sleep Duration ↔ Daily Steps",
      coefficient: sleepVsSteps,
      strength: strengthLabel(sleepVsSteps),
      direction: directionLabel(sleepVsSteps),
      interpretation: sleepVsSteps && sleepVsSteps > 0.3 ?
        "Better sleep → More activity (Good!)" :
        sleepVsSteps && sleepVsSteps < -0.3 ?
        "Better sleep → Less activity (Unexpected)" :
        "No strong pattern detected",
      n: sleepToSteps.length
    },
    {
      relationship: "Med Timing Variability → BP Variability",
      coefficient: medTimingVsBPControl,
      strength: strengthLabel(medTimingVsBPControl),
      direction: directionLabel(medTimingVsBPControl),
      interpretation: medTimingVsBPControl && medTimingVsBPControl > 0.3 ?
        "Inconsistent timing → Variable BP (Take meds at same time!)" :
        medTimingVsBPControl && medTimingVsBPControl < -0.3 ?
        "Inconsistent timing → Stable BP (Unexpected)" :
        "No strong pattern detected",
      n: windows.length
    },
    {
      relationship: "Weight ↔ Systolic BP",
      coefficient: weightVsBP,
      strength: strengthLabel(weightVsBP),
      direction: directionLabel(weightVsBP),
      interpretation: weightVsBP && weightVsBP > 0.3 ?
        "Higher weight → Higher BP (Common pattern)" :
        weightVsBP && weightVsBP < -0.3 ?
        "Higher weight → Lower BP (Unexpected)" :
        "No strong pattern detected",
      n: weightToBP.length
    }
  ];

  const correlationCols = [
    { id: "relationship", title: "Relationship", value: r => r.relationship },
    { id: "coefficient", title: "r", value: r => num(r.coefficient, 3) },
    { id: "strength", title: "Strength", value: r => r.strength },
    { id: "direction", title: "Direction", value: r => r.direction },
    { id: "interpretation", title: "Interpretation", value: r => r.interpretation },
    { id: "n", title: "Data Points", value: r => r.n }
  ];

  // ===== SCATTER PLOT DATA (Text-based summary) =====
  const scatterRows = [
    {
      metric: "Sleep vs Next-Day Systolic BP",
      avgX: mean(sleepToBP.map(d => d.sleep)),
      avgY: mean(sleepToBP.map(d => d.sys)),
      r: sleepVsSys
    },
    {
      metric: "Steps vs Weight",
      avgX: mean(stepsToWeight.map(d => d.steps)),
      avgY: mean(stepsToWeight.map(d => d.weight)),
      r: stepsVsWeight
    },
    {
      metric: "Sleep vs Steps",
      avgX: mean(sleepToSteps.map(d => d.sleep)),
      avgY: mean(sleepToSteps.map(d => d.steps)),
      r: sleepVsSteps
    }
  ];

  const scatterCols = [
    { id: "metric", title: "Metric Pair", value: r => r.metric },
    { id: "avgX", title: "Average X", value: r => num(r.avgX, 1) },
    { id: "avgY", title: "Average Y", value: r => num(r.avgY, 1) },
    { id: "r", title: "Correlation", value: r => num(r.r, 3) }
  ];

  return (
    <div>
      <h3>Correlation Analysis</h3>
      <dc.Table columns={correlationCols} rows={correlationRows} />

      <h3>Summary Statistics</h3>
      <dc.Table columns={scatterCols} rows={scatterRows} />

      <h3>Notes</h3>
      <ul>
        <li><strong>Correlation coefficients (r)</strong> range from -1 to +1</li>
        <li><strong>Positive</strong>: Both metrics move in the same direction</li>
        <li><strong>Negative</strong>: Metrics move in opposite directions</li>
        <li><strong>Strength</strong>: Weak (0-0.3), Moderate (0.3-0.7), Strong (0.7-1.0)</li>
        <li><strong>Important</strong>: Correlation does not prove causation. Discuss patterns with your doctor.</li>
      </ul>
    </div>
  );
}
```
