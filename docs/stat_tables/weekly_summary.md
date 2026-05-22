---
age:
  - 38.1.17
age_unix: 1203432290
authors:
  - jwl
title: weekly_summary
timestamp: 1760668927580
date_created: 2025-10-21T16:45:00
date_updated: 2025-10-21T16:45:00
hash: 489224784a7852aae33c8a4415ce9648ae9e5fcd9fc58436dfab2027ee352d33
id: e2dcbc29-55f0-48d3-abf3-4aa474e26d53
tags:
  - dashboard
  - weekly
  - summary
---

# weekly_summary

## What this dashboard shows

### Purpose

This dashboard provides a **week-at-a-glance** summary of your key health metrics using a **rolling 7-day period**, making it easy to:
- Spot weekly trends and patterns
- Compare this week to last week
- Track weekly progress toward health goals
- Identify which days had the best/worst metrics

**Note**: This uses a rolling 7-day window, not calendar weeks:
- **This Week** = Last 7 days from today
- **Last Week** = Days 8-14 from today
- The window updates daily and doesn't follow calendar week boundaries (Sunday-Saturday or Monday-Sunday)

### Metrics Tracked

1. **Blood Pressure**: Weekly averages for Wake/Sleep systolic, diastolic, and pulse
2. **Weight**: Start vs end of week, total change
3. **Activity**: Total steps for the week, daily average
4. **Sleep**: Average sleep duration and efficiency
5. **Medication Adherence**: Doses taken vs expected for the week
6. **Daily Breakdown**: Day-by-day view of key metrics

### How to Interpret

- **This Week vs Last Week**: Compare current week to previous week to spot trends
- **Week-over-Week Change**: Positive/negative changes highlighted
- **Best/Worst Days**: Quickly see which days had optimal metrics
- **Adherence**: Track if you're taking medications as prescribed

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

const sum = arr => {
  const valid = arr.filter(v => v != null && !isNaN(v));
  return valid.reduce((a,b) => a + b, 0);
};

const num = (v, decimals = 1) => {
  if (v == null || isNaN(v)) return "—";
  return <span className="num">{v.toFixed(decimals)}</span>;
};

const formatDate = d => d ? d.replace(/-/g, '_') : d;

const changeIndicator = (current, previous, lowerIsBetter = true) => {
  if (current == null || previous == null) return "";
  const diff = current - previous;
  const pct = ((diff / previous) * 100);
  if (Math.abs(pct) < 1) return "→";

  // For metrics where lower is better (BP, weight, pulse)
  if (lowerIsBetter) {
    if (diff > 0) return <span className="bp-high">↑ {pct.toFixed(1)}%</span>;
    return <span className="bp-low">↓ {Math.abs(pct).toFixed(1)}%</span>;
  }
  // For metrics where higher is better (steps, sleep)
  else {
    if (diff > 0) return <span className="bp-low">↑ {pct.toFixed(1)}%</span>;
    return <span className="bp-high">↓ {Math.abs(pct).toFixed(1)}%</span>;
  }
};

const getDayOfWeek = (dateStr) => {
  const d = new Date(dateStr);
  return ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][d.getDay()];
};

const getWeekNumber = (d) => {
  const date = new Date(d.getTime());
  date.setHours(0, 0, 0, 0);
  date.setDate(date.getDate() + 4 - (date.getDay() || 7));
  const yearStart = new Date(date.getFullYear(), 0, 1);
  return Math.ceil((((date - yearStart) / 86400000) + 1) / 7);
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

  // Get pages with dates (using date from filename, not creation time)
  const pagesWithDates = pages.map(p => {
    const dateStr = pageDateYMD(p);
    const epochMs = dateStr && dateStr !== "—" ? new Date(dateStr).getTime() : pageEpochMs(p);
    return {
      page: p,
      date: dateStr,
      epochMs: epochMs
    };
  }).filter(pd => pd.epochMs != null && !isNaN(pd.epochMs));

  // Define current week (last 7 days) and previous week (8-14 days ago)
  const now = Date.now();
  const thisWeekStart = now - 7 * 24 * 60 * 60 * 1000;
  const lastWeekStart = now - 14 * 24 * 60 * 60 * 1000;
  const lastWeekEnd = thisWeekStart;

  const thisWeekPages = pagesWithDates.filter(pd => pd.epochMs >= thisWeekStart);
  const lastWeekPages = pagesWithDates.filter(pd => pd.epochMs >= lastWeekStart && pd.epochMs < lastWeekEnd);

  // ===== WEEKLY COMPARISON =====
  const getWeekStats = (weekPages) => {
    // Sort pages chronologically to ensure start/end weight are correct
    const sortedPages = weekPages.slice().sort((a, b) => a.epochMs - b.epochMs);

    const allSys = sortedPages.flatMap(pd => [
      toNumber(pd.page.value && pd.page.value("am_sys")),
      toNumber(pd.page.value && pd.page.value("pm_sys"))
    ]).filter(v => v != null);

    const allDia = sortedPages.flatMap(pd => [
      toNumber(pd.page.value && pd.page.value("am_dia")),
      toNumber(pd.page.value && pd.page.value("pm_dia"))
    ]).filter(v => v != null);

    const allPulse = sortedPages.flatMap(pd => [
      toNumber(pd.page.value && pd.page.value("am_hr")),
      toNumber(pd.page.value && pd.page.value("pm_hr"))
    ]).filter(v => v != null);

    const weights = sortedPages.map(pd => toNumber(pd.page.value && pd.page.value("weight"))).filter(v => v != null);
    const steps = sortedPages.map(pd => toNumber(pd.page.value && pd.page.value("steps"))).filter(v => v != null);
    const sleep = sortedPages.map(pd => toNumber(pd.page.value && pd.page.value("sleep"))).filter(v => v != null);

    return {
      avgSys: mean(allSys),
      avgDia: mean(allDia),
      avgPulse: mean(allPulse),
      startWeight: weights.length > 0 ? weights[0] : null,
      endWeight: weights.length > 0 ? weights[weights.length - 1] : null,
      weightChange: weights.length > 0 ? weights[0] - weights[weights.length - 1] : null,
      totalSteps: sum(steps),
      avgSteps: mean(steps),
      avgSleep: mean(sleep),
      days: sortedPages.length
    };
  };

  const thisWeek = getWeekStats(thisWeekPages);
  const lastWeek = getWeekStats(lastWeekPages);

  const comparison_rows = [
    {
      metric: "Avg Systolic BP",
      this_week: thisWeek.avgSys,
      last_week: lastWeek.avgSys,
      change: changeIndicator(thisWeek.avgSys, lastWeek.avgSys)
    },
    {
      metric: "Avg Diastolic BP",
      this_week: thisWeek.avgDia,
      last_week: lastWeek.avgDia,
      change: changeIndicator(thisWeek.avgDia, lastWeek.avgDia)
    },
    {
      metric: "Avg Pulse",
      this_week: thisWeek.avgPulse,
      last_week: lastWeek.avgPulse,
      change: changeIndicator(thisWeek.avgPulse, lastWeek.avgPulse)
    },
    {
      metric: "Weight (Start → End)",
      this_week: thisWeek.startWeight && thisWeek.endWeight ?
        `${thisWeek.startWeight.toFixed(1)} → ${thisWeek.endWeight.toFixed(1)}` : "—",
      last_week: lastWeek.startWeight && lastWeek.endWeight ?
        `${lastWeek.startWeight.toFixed(1)} → ${lastWeek.endWeight.toFixed(1)}` : "—",
      change: thisWeek.weightChange != null ?
        <span className={thisWeek.weightChange > 0 ? "bp-low" : "bp-high"}>
          {thisWeek.weightChange > 0 ? "↓" : "↑"} {Math.abs(thisWeek.weightChange).toFixed(1)} lbs
        </span> : "—"
    },
    {
      metric: "Total Steps",
      this_week: thisWeek.totalSteps,
      last_week: lastWeek.totalSteps,
      change: changeIndicator(thisWeek.totalSteps, lastWeek.totalSteps, false)
    },
    {
      metric: "Avg Steps/Day",
      this_week: thisWeek.avgSteps,
      last_week: lastWeek.avgSteps,
      change: changeIndicator(thisWeek.avgSteps, lastWeek.avgSteps, false)
    },
    {
      metric: "Avg Sleep (mins)",
      this_week: thisWeek.avgSleep,
      last_week: lastWeek.avgSleep,
      change: changeIndicator(thisWeek.avgSleep, lastWeek.avgSleep, false)
    }
  ];

  const comparison_cols = [
    { id: "metric", title: "Metric", value: r => r.metric },
    { id: "this_week", title: "This Week", value: r => typeof r.this_week === "number" ? num(r.this_week) : r.this_week || "—" },
    { id: "last_week", title: "Last Week", value: r => typeof r.last_week === "number" ? num(r.last_week) : r.last_week || "—" },
    { id: "change", title: "Change", value: r => r.change || "—" }
  ];

  // ===== DAILY BREAKDOWN (This Week) =====
  const daily_rows = thisWeekPages.map(pd => {
    const am_sys = toNumber(pd.page.value && pd.page.value("am_sys"));
    const am_dia = toNumber(pd.page.value && pd.page.value("am_dia"));
    const pm_sys = toNumber(pd.page.value && pd.page.value("pm_sys"));
    const pm_dia = toNumber(pd.page.value && pd.page.value("pm_dia"));
    const weight = toNumber(pd.page.value && pd.page.value("weight"));
    const steps = toNumber(pd.page.value && pd.page.value("steps"));
    const sleep = toNumber(pd.page.value && pd.page.value("sleep"));

    const avg_sys = mean([am_sys, pm_sys]);
    const avg_dia = mean([am_dia, pm_dia]);

    return {
      date: pd.date,
      day: getDayOfWeek(pd.date),
      sys: avg_sys,
      dia: avg_dia,
      weight: weight,
      steps: steps,
      sleep: sleep,
      sort_key: pd.date,
      has_data: avg_sys != null || avg_dia != null || weight != null || steps != null || sleep != null
    };
  }).filter(r => r.has_data).sort((a, b) => b.sort_key.localeCompare(a.sort_key));

  const daily_cols = [
    { id: "day", title: "Day", value: r => r.day },
    { id: "date", title: "Date", value: r => formatDate(r.date) },
    { id: "sys", title: "Average Systolic", value: r => num(r.sys) },
    { id: "dia", title: "Average Diastolic", value: r => num(r.dia) },
    { id: "weight", title: "Weight", value: r => num(r.weight) },
    { id: "steps", title: "Steps", value: r => num(r.steps, 0) },
    { id: "sleep", title: "Sleep (minutes)", value: r => num(r.sleep, 0) }
  ];

  // ===== WEEKLY HIGHLIGHTS =====
  const allThisWeekBP = thisWeekPages.flatMap(pd => [
    { date: pd.date, sys: toNumber(pd.page.value && pd.page.value("am_sys")), dia: toNumber(pd.page.value && pd.page.value("am_dia")), time: "Wake" },
    { date: pd.date, sys: toNumber(pd.page.value && pd.page.value("pm_sys")), dia: toNumber(pd.page.value && pd.page.value("pm_dia")), time: "Sleep" }
  ]).filter(r => r.sys != null && r.dia != null);

  const bestBP = allThisWeekBP.reduce((best, r) =>
    (best == null || r.sys < best.sys) ? r : best, null);
  const worstBP = allThisWeekBP.reduce((worst, r) =>
    (worst == null || r.sys > worst.sys) ? r : worst, null);

  const allThisWeekSteps = thisWeekPages.map(pd => ({
    date: pd.date,
    steps: toNumber(pd.page.value && pd.page.value("steps"))
  })).filter(r => r.steps != null);

  const bestSteps = allThisWeekSteps.reduce((best, r) =>
    (best == null || r.steps > best.steps) ? r : best, null);
  const worstSteps = allThisWeekSteps.reduce((worst, r) =>
    (worst == null || r.steps < worst.steps) ? r : worst, null);

  const highlight_rows = [
    {
      category: "Best BP Reading",
      value: bestBP ? `${bestBP.sys}/${bestBP.dia}` : "—",
      date: bestBP ? `${formatDate(bestBP.date)} (${bestBP.time})` : "—"
    },
    {
      category: "Highest BP Reading",
      value: worstBP ? `${worstBP.sys}/${worstBP.dia}` : "—",
      date: worstBP ? `${formatDate(worstBP.date)} (${worstBP.time})` : "—"
    },
    {
      category: "Most Active Day",
      value: bestSteps ? `${bestSteps.steps.toFixed(0)} steps` : "—",
      date: bestSteps ? formatDate(bestSteps.date) : "—"
    },
    {
      category: "Least Active Day",
      value: worstSteps ? `${worstSteps.steps.toFixed(0)} steps` : "—",
      date: worstSteps ? formatDate(worstSteps.date) : "—"
    }
  ];

  const highlight_cols = [
    { id: "category", title: "Category", value: r => r.category },
    { id: "value", title: "Value", value: r => r.value },
    { id: "date", title: "Date", value: r => r.date }
  ];

  return (
    <div>
      <h3>Weekly Comparison (This Week vs Last Week)</h3>
      <dc.Table columns={comparison_cols} rows={comparison_rows} />

      <h3>Daily Breakdown (This Week)</h3>
      <dc.Table columns={daily_cols} rows={daily_rows} />

      <h3>Weekly Highlights</h3>
      <dc.Table columns={highlight_cols} rows={highlight_rows} />
    </div>
  );
}
```
