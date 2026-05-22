---
age:
  - 38.1.17
age_unix: 1203432290
authors:
  - jwl
title: dietitian_report
timestamp: 1760668927580
date_created: 2025-10-25T00:00:00
date_updated: 2025-10-28T15:25:28
hash: 9bd2517498830bdf1f62f3cb1c66e07f1be96faa128f745a29013601cb2cb65f
id: 0a75b506-1819-4807-92a2-78af3222b237
tags:
  - 12_week_trends
  - dashboard
  - dietitian
  - weight_loss
---

# dietitian_report

## What this dashboard shows

### Purpose

This report provides a **comprehensive 12-week rolling window** of weight loss progress and supporting health metrics, specifically designed for dietitian consultations. It focuses on the **big picture trends** rather than daily fluctuations, making it easy to:

- Track overall weight loss progress against goals
- Identify patterns in weekly weight changes
- Correlate activity levels with weight loss success
- Monitor supporting health indicators (BP, sleep)
- Spot which weeks had the best/worst outcomes
- Export clean, professional PDF reports for appointments

**Target Goal**: 5 lbs/month (2.2 kg/month) or approximately 1.25 lbs/week (0.57 kg/week)

### What "12-week rolling window" means

Unlike calendar-based reports, this uses a **rolling 12-week period**:
- Always shows the **last 84 days** from today
- Updates automatically as you add new journal entries
- Weeks are Monday-Sunday periods
- The window moves forward each day, dropping old data and adding new

This approach ensures you're always looking at recent, relevant data for consultations.

### Tables Included

#### 1. 12-Week Summary

A high-level snapshot showing:
- Total time period covered (actual weeks of data)
- Starting weight → Current weight
- Total weight loss achieved
- Average weekly rate vs goal rate
- Status indicator (On Track / Behind Goal)

#### 2. Weekly Weight & Activity Trends

Week-by-week breakdown showing:
- **Week Ending**: Sunday date for each Monday-Sunday period
- **Weight (Start → End)**: First and last weight recorded that week
- **Change**: Net weight change for the week (positive = loss)
- **Ahead/Behind Goal**: How much you exceeded or fell short of the 1.25 lbs/week target
  - Positive values (e.g., +0.50) = exceeded goal, ahead of target
  - Negative values (e.g., -1.00) = fell short of goal, behind target
  - Example: -1.00 means you lost 1.00 lbs less than the 1.25 lb goal
- **Avg Steps/Day**: Activity level indicator
- **Days**: Number of journal entries that week (may have incomplete metrics)

#### 3. Weekly Health Indicators

Supporting metrics that affect weight loss:
- **Avg Steps/Day**: Daily activity level (highest/lowest highlighted)
- **Total Steps**: Weekly activity volume (highest/lowest highlighted)
- **Avg Systolic (mmHg)**: Average systolic blood pressure (upper number) for the week (lowest/highest highlighted)
- **Avg Diastolic (mmHg)**: Average diastolic blood pressure (lower number) for the week (lowest/highest highlighted)
- **Avg MAP (mmHg)**: Mean Arterial Pressure - a clinically meaningful measure of average blood pressure during a cardiac cycle. MAP represents the average pressure in the arteries and is calculated using the formula: MAP = diastolic + (systolic - diastolic) / 3. This weighted average accounts for the fact that the heart spends more time in diastole than systole, providing a single value that better represents overall cardiovascular pressure than either number alone (lowest/highest highlighted)
- **Avg Sleep (min)**: Sleep duration affects metabolism and weight loss (highest/lowest highlighted)

#### 4. Monthly Summary

Higher-level view grouping weeks into months:
- Net weight change per month (lost or gained)
- Average daily steps
- Days tracked (data quality indicator)

### How to Read the Data

**Weight Values**: All weights shown in both imperial and metric
- Example: `389.0 lbs (176.4 kg)`
- Start → End shows direction of change within the period

**Change Values**:
- The report shows changes as **“X lbs lost”** or **“X lbs gained”**.
- Losses are shown in green, gains in red.
- All changes are relative to the **start of that week or month**, not your all-time total.

**Ahead/Behind Goal Column**: Shows if weekly loss exceeded or fell short of target
- **Positive values** (e.g., +0.50 lbs) = exceeded goal by 0.5 lbs (ahead of schedule)
- **Negative values** (e.g., -0.30 lbs) = fell short by 0.3 lbs (behind schedule)
- **Zero (0.00 lbs)** = exactly met the goal
- Formula: (Actual Loss) - (1.25 lb Goal)

**Status Indicators**:
- `✓ On Track` = Average rate ≥ 90% of goal (1.13+ lbs/week)
- `⚠️ Slightly Behind` = Average rate 70-90% of goal (0.88-1.12 lbs/week)
- `⚠️ Behind Goal` = Average rate < 70% of goal (<0.88 lbs/week)

### Color Coding & Visual Highlights

The tables use color to make important patterns immediately visible:

**Color Classes**:
- `.bp-low` (blue/green) = **Good outcomes**
  - Highest weight loss
  - Highest activity levels
  - Meeting/exceeding goals
- `.bp-high` (red) = **Concerning patterns**
  - Weight gain or minimal loss
  - Low activity levels
  - Well below goal

**What gets highlighted**:
- **Best week for weight loss** (highest change value)
- **Worst week for weight loss** (lowest change value or gains)
- **Best week for activity** (highest average steps)
- **Worst week for activity** (lowest average steps)
- **Best month** (highest monthly loss)
- **Goal achievement** (weeks exceeding target get positive indicators)

### Units: Imperial & Metric

All weight measurements show both units:
- **Imperial** (pounds, lbs): Primary unit for US healthcare
- **Metric** (kilograms, kg): Standard international unit

Both are included to accommodate different medical professionals and personal preference. Goal rates are also shown in both units.

### Important Notes

**Data Quality**:
- Accuracy depends on consistent daily tracking
- "Days Tracked" column shows data completeness
- Missing days may affect weekly averages
- Weight fluctuations are normal; focus on trends

**Interpretation**:
- Weekly variations are expected (water weight, etc.)
- Look for overall trend direction across multiple weeks
- Consider context: illness, travel, special events
- Activity strongly correlates with weight loss success

**Rolling Window Behavior**:
- Very recent data (last few days) may show incomplete weeks
- Data updates automatically as you add journal entries
- Historical corrections will retroactively update calculations
- "Time Period" shows actual weeks of data (may be less than 12 initially)

**For Appointments**:
- Print/export this report before consultations
- Colors and formatting export well to PDF
- Add manual notes about context (illness, travel, etc.)
- Compare multiple reports over time to see long-term progress

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
  } catch { }
  return p.$name || "—";
};

const mean = arr => {
  const valid = arr.filter(v => v != null && !isNaN(v));
  return valid.length ? valid.reduce((a, b) => a + b, 0) / valid.length : null;
};

const sum = arr => {
  const valid = arr.filter(v => v != null && !isNaN(v));
  return valid.reduce((a, b) => a + b, 0);
};

const num = (v, decimals = 1) => {
  if (v == null || isNaN(v)) return "—";
  return <span className="num">{v.toFixed(decimals)}</span>;
};

const weight = (lbs, decimals = 1) => {
  if (lbs == null || isNaN(lbs)) return "—";
  const kg = lbs * 0.453592;
  return <span className="num">{lbs.toFixed(decimals)} lbs ({kg.toFixed(decimals)} kg)</span>;
};

const weightRate = (lbsPerWeek) => {
  if (lbsPerWeek == null || isNaN(lbsPerWeek)) return "—";
  const kgPerWeek = lbsPerWeek * 0.453592;
  return <span className="num">{lbsPerWeek.toFixed(2)} lbs/week ({kgPerWeek.toFixed(2)} kg/week)</span>;
};

const formatDate = d => d ? d.replace(/-/g, '_') : d;

const parseLocalDate = (ymd) => {
  const [y, m, d] = ymd.split("-").map(Number);
  return new Date(y, m - 1, d); // local midnight
};

const getDayOfWeek = (dateStr) => {
  const d = parseLocalDate(dateStr);
  return ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][d.getDay()];
};

const getMonday = (dateInput) => {
  // Handle both string and Date inputs
  const date = typeof dateInput === 'string' ? parseLocalDate(dateInput) : new Date(dateInput);
  const day = date.getDay(); // 0=Sun, 1=Mon, 2=Tue, etc.

  // Calculate days to subtract to get to Monday
  // If Sunday (0), go back 6 days; otherwise go back (day - 1) days
  const daysToSubtract = day === 0 ? 6 : (day - 1);

  // Use calendar math with local date
  const monday = new Date(date);
  monday.setDate(monday.getDate() - daysToSubtract);
  return monday;
};

const formatWeekEnding = (mondayDate) => {
  // Use calendar math: add 6 days to Monday to get Sunday
  const sunday = new Date(mondayDate);
  sunday.setDate(sunday.getDate() + 6);

  const year = sunday.getFullYear();
  const month = String(sunday.getMonth() + 1).padStart(2, '0');
  const day = String(sunday.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
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
    const epochMs = dateStr && dateStr !== "—" ? parseLocalDate(dateStr).getTime() : null;
    return {
      page: p,
      date: dateStr,
      epochMs: epochMs
    };
  }).filter(pd => pd.epochMs != null && !isNaN(pd.epochMs))
    .sort((a, b) => a.epochMs - b.epochMs);

  // ===== 12-WEEK WINDOW =====
  const now = Date.now();
  const twelveWeeksAgo = now - 12 * 7 * 24 * 60 * 60 * 1000;
  const last12Weeks = pagesWithDates.filter(pd => pd.epochMs >= twelveWeeksAgo);

  // ===== OVERALL 12-WEEK SUMMARY =====
  const weights = last12Weeks.map(pd => toNumber(pd.page.value && pd.page.value("weight"))).filter(v => v != null);
  const startWeight = weights.length > 0 ? weights[0] : null;
  const endWeight = weights.length > 0 ? weights[weights.length - 1] : null;
  const totalLoss = startWeight && endWeight ? startWeight - endWeight : null;

  // Calculate actual number of weeks
  const actualWeeks = last12Weeks.length > 0 ?
    (last12Weeks[last12Weeks.length - 1].epochMs - last12Weeks[0].epochMs) / (7 * 24 * 60 * 60 * 1000) : null;
  const avgWeeklyRate = totalLoss && actualWeeks ? totalLoss / actualWeeks : null;

  const goalRate = 1.25; // lbs per week
  const goalRateKg = goalRate * 0.453592;

  // Calculate status with color info
  let statusText = "—";
  let statusClass = "";
  if (avgWeeklyRate && goalRate) {
    if (avgWeeklyRate >= goalRate * 0.9) {
      statusText = "✓ On Track";
      statusClass = "bp-low";
    } else if (avgWeeklyRate >= goalRate * 0.7) {
      statusText = "⚠️ Slightly Behind";
      statusClass = "";
    } else {
      statusText = "⚠️ Behind Goal";
      statusClass = "bp-high";
    }
  }

  const summaryRows = [
    {
      metric: "Time Period",
      value: actualWeeks ? `${actualWeeks.toFixed(1)} weeks` : "—",
      isStatus: false
    },
    {
      metric: "Starting Weight",
      value: startWeight ? weight(startWeight) : "—",
      isStatus: false
    },
    {
      metric: "Current Weight",
      value: endWeight ? weight(endWeight) : "—",
      isStatus: false
    },
    {
      metric: "Total Change",
      value: (() => {
        if (totalLoss == null) return "—";
        const lbs = Math.abs(totalLoss);
        const kg = Math.abs(totalLoss * 0.453592);

        if (totalLoss > 0) {
          return `${lbs.toFixed(1)} lbs lost (${kg.toFixed(1)} kg)`;
        } else if (totalLoss < 0) {
          return `${lbs.toFixed(1)} lbs gained (${kg.toFixed(1)} kg)`;
        }
        return "No change";
      })(),
      isStatus: false
    },
    {
      metric: "Average Rate",
      value: avgWeeklyRate ? weightRate(avgWeeklyRate) : "—",
      isStatus: false
    },
    {
      metric: "Goal Rate",
      value: `${goalRate.toFixed(2)} lbs/week (${goalRateKg.toFixed(2)} kg/week)`,
      isStatus: false
    },
    {
      metric: "Status",
      value: statusText,
      isStatus: true,
      statusClass: statusClass
    }
  ];

  const summaryCols = [
    { id: "metric", title: "Metric", value: r => r.metric },
    {
      id: "value", title: "Value", value: r => {
        if (r.isStatus && r.statusClass) {
          return <span className={r.statusClass}>{r.value}</span>;
        }
        return r.value;
      }
    }
  ];

  // ===== WEEKLY BREAKDOWN =====
  // Group pages by week (Monday-Sunday)
  const weekMap = {};

  for (const pd of last12Weeks) {
    const date = new Date(pd.epochMs);
    const monday = getMonday(date);
    // Format as local date string for weekKey
    const year = monday.getFullYear();
    const month = String(monday.getMonth() + 1).padStart(2, '0');
    const day = String(monday.getDate()).padStart(2, '0');
    const weekKey = `${year}-${month}-${day}`;

    if (!weekMap[weekKey]) {
      weekMap[weekKey] = [];
    }
    weekMap[weekKey].push(pd);
  }

  // Calculate stats for each week
  const weeklyData = Object.keys(weekMap).sort().map(weekKey => {
    const weekPages = weekMap[weekKey];
    const weekEnd = formatWeekEnding(parseLocalDate(weekKey));

    // Weight
    const weekWeights = weekPages.map(pd => toNumber(pd.page.value && pd.page.value("weight"))).filter(v => v != null);
    const weekStartWeight = weekWeights.length > 0 ? weekWeights[0] : null;
    const weekEndWeight = weekWeights.length > 0 ? weekWeights[weekWeights.length - 1] : null;
    const weekChange = weekStartWeight && weekEndWeight ? weekStartWeight - weekEndWeight : null;

    // Steps
    const weekSteps = weekPages.map(pd => toNumber(pd.page.value && pd.page.value("steps"))).filter(v => v != null);
    const avgSteps = mean(weekSteps);
    const totalSteps = sum(weekSteps);

    // BP
    const weekSys = weekPages.flatMap(pd => [
      toNumber(pd.page.value && pd.page.value("am_sys")),
      toNumber(pd.page.value && pd.page.value("pm_sys"))
    ]).filter(v => v != null);
    const weekDia = weekPages.flatMap(pd => [
      toNumber(pd.page.value && pd.page.value("am_dia")),
      toNumber(pd.page.value && pd.page.value("pm_dia"))
    ]).filter(v => v != null);
    const avgSys = mean(weekSys);
    const avgDia = mean(weekDia);
    const avgMAP = avgSys && avgDia ? avgDia + (avgSys - avgDia) / 3 : null;

    // Sleep
    const weekSleep = weekPages.map(pd => toNumber(pd.page.value && pd.page.value("sleep"))).filter(v => v != null);
    const avgSleep = mean(weekSleep);

    // Days tracked
    const daysTracked = weekPages.length;

    return {
      weekEnd: weekEnd,
      startWeight: weekStartWeight,
      endWeight: weekEndWeight,
      change: weekChange,
      avgSteps: avgSteps,
      totalSteps: totalSteps,
      avgSys: avgSys,
      avgDia: avgDia,
      avgMAP: avgMAP,
      avgSleep: avgSleep,
      daysTracked: daysTracked,
      vsGoal: weekChange != null && goalRate ? weekChange - goalRate : null
    };
  }).reverse(); // Most recent first

  const weeklyRows = weeklyData;

  // Calculate extremes for highlighting
  const validWeightChanges = weeklyData.map(w => w.change).filter(v => v != null);
  const bestWeightLoss = validWeightChanges.length > 0 ? Math.max(...validWeightChanges) : null;
  const worstWeightLoss = validWeightChanges.length > 0 ? Math.min(...validWeightChanges) : null;

  const validSteps = weeklyData.map(w => w.avgSteps).filter(v => v != null);
  const bestSteps = validSteps.length > 0 ? Math.max(...validSteps) : null;
  const worstSteps = validSteps.length > 0 ? Math.min(...validSteps) : null;

  const weeklyCols = [
    { id: "weekEnd", title: "Week Ending", value: r => formatDate(r.weekEnd) },
    {
      id: "weight", title: "Weight (Start → End)", value: r => {
        if (r.startWeight == null || r.endWeight == null) return "—";
        const startKg = (r.startWeight * 0.453592).toFixed(1);
        const endKg = (r.endWeight * 0.453592).toFixed(1);
        return `${r.startWeight.toFixed(1)} → ${r.endWeight.toFixed(1)} lbs (${startKg} → ${endKg} kg)`;
      }
    },
    {
      id: "change", title: "Change", value: r => {
        if (r.change == null) return "—";

        const isLoss = r.change > 0;
        const isGain = r.change < 0;

        if (!isLoss && !isGain) {
          return "No change";
        }

        const lbs = Math.abs(r.change);
        const kg = Math.abs(r.change * 0.453592);

        const label = isLoss ? "lost" : "gained";
        const className = isLoss ? "bp-low" : "bp-high"; // loss = green, gain = red

        return (
          <span className={className}>
            {lbs.toFixed(1)} lbs {label} ({kg.toFixed(1)} kg)
          </span>
        );
      }
    },

    {
      id: "vsGoal", title: "Ahead/Behind Goal", value: r => {
        if (r.vsGoal == null) return "—";
        const vsGoalKg = (r.vsGoal * 0.453592).toFixed(2);
        const sign = r.vsGoal >= 0 ? "+" : "";
        // Positive vsGoal = ahead of goal (good), negative = behind goal
        const className = r.vsGoal >= 0 ? "bp-low" : "";
        return (
          <span className={className}>
            {sign}{r.vsGoal.toFixed(2)} lbs ({sign}{vsGoalKg} kg)
          </span>
        );
      }
    },
    {
      id: "avgSteps", title: "Avg Steps/Day", value: r => {
        if (r.avgSteps == null) return "—";
        const isBest = r.avgSteps === bestSteps;
        const isWorst = r.avgSteps === worstSteps;
        const className = isBest ? "bp-low" : isWorst ? "bp-high" : "";
        return <span className={className + " num"}>{r.avgSteps.toFixed(0)}</span>;
      }
    },
    { id: "days", title: "Days", value: r => r.daysTracked }
  ];

  // ===== ACTIVITY & HEALTH TRENDS =====
  const healthRows = weeklyData.map(w => ({
    weekEnd: w.weekEnd,
    avgSteps: w.avgSteps,
    totalSteps: w.totalSteps,
    avgSys: w.avgSys,
    avgDia: w.avgDia,
    avgMAP: w.avgMAP,
    avgSleep: w.avgSleep
  }));

  // Calculate extremes for health metrics
  const validTotalSteps = healthRows.map(h => h.totalSteps).filter(v => v != null);
  const bestTotalSteps = validTotalSteps.length > 0 ? Math.max(...validTotalSteps) : null;
  const worstTotalSteps = validTotalSteps.length > 0 ? Math.min(...validTotalSteps) : null;

  const validSleep = healthRows.map(h => h.avgSleep).filter(v => v != null);
  const bestSleep = validSleep.length > 0 ? Math.max(...validSleep) : null;
  const worstSleep = validSleep.length > 0 ? Math.min(...validSleep) : null;

  // For BP, calculate extremes for systolic, diastolic, and MAP - lower is better for all
  const validSys = healthRows.map(h => h.avgSys).filter(v => v != null);
  const bestSys = validSys.length > 0 ? Math.min(...validSys) : null;
  const worstSys = validSys.length > 0 ? Math.max(...validSys) : null;

  const validDia = healthRows.map(h => h.avgDia).filter(v => v != null);
  const bestDia = validDia.length > 0 ? Math.min(...validDia) : null;
  const worstDia = validDia.length > 0 ? Math.max(...validDia) : null;

  const validMAP = healthRows.map(h => h.avgMAP).filter(v => v != null);
  const bestMAP = validMAP.length > 0 ? Math.min(...validMAP) : null;
  const worstMAP = validMAP.length > 0 ? Math.max(...validMAP) : null;

  const healthCols = [
    { id: "weekEnd", title: "Week Ending", value: r => formatDate(r.weekEnd) },
    {
      id: "avgSteps", title: "Avg Steps/Day", value: r => {
        if (r.avgSteps == null || r.avgSteps === "—") return "—";
        const stepsVal = typeof r.avgSteps === "string" ? null : r.avgSteps;
        if (stepsVal == null) return "—";
        const isBest = stepsVal === bestSteps;
        const isWorst = stepsVal === worstSteps;
        const className = isBest ? "bp-low" : isWorst ? "bp-high" : "";
        return <span className={className + " num"}>{stepsVal.toFixed(0)}</span>;
      }
    },
    {
      id: "totalSteps", title: "Total Steps", value: r => {
        if (r.totalSteps == null) return "—";
        const isBest = r.totalSteps === bestTotalSteps;
        const isWorst = r.totalSteps === worstTotalSteps;
        const className = isBest ? "bp-low" : isWorst ? "bp-high" : "";
        return <span className={className + " num"}>{r.totalSteps.toFixed(0)}</span>;
      }
    },
    {
      id: "avgSys", title: "Avg Systolic (mmHg)", value: r => {
        if (r.avgSys == null) return "—";
        const isBest = r.avgSys === bestSys;
        const isWorst = r.avgSys === worstSys;
        const className = isBest ? "bp-low" : isWorst ? "bp-high" : "";
        return <span className={className + " num"}>{r.avgSys.toFixed(1)}</span>;
      }
    },
    {
      id: "avgDia", title: "Avg Diastolic (mmHg)", value: r => {
        if (r.avgDia == null) return "—";
        const isBest = r.avgDia === bestDia;
        const isWorst = r.avgDia === worstDia;
        const className = isBest ? "bp-low" : isWorst ? "bp-high" : "";
        return <span className={className + " num"}>{r.avgDia.toFixed(1)}</span>;
      }
    },
    {
      id: "avgMAP", title: "Avg MAP (mmHg)", value: r => {
        if (r.avgMAP == null) return "—";
        const isBest = r.avgMAP === bestMAP;
        const isWorst = r.avgMAP === worstMAP;
        const className = isBest ? "bp-low" : isWorst ? "bp-high" : "";
        return <span className={className + " num"}>{r.avgMAP.toFixed(1)}</span>;
      }
    },
    {
      id: "avgSleep", title: "Avg Sleep (min)", value: r => {
        if (r.avgSleep == null) return "—";
        const isBest = r.avgSleep === bestSleep;
        const isWorst = r.avgSleep === worstSleep;
        const className = isBest ? "bp-low" : isWorst ? "bp-high" : "";
        return <span className={className + " num"}>{r.avgSleep.toFixed(0)}</span>;
      }
    }
  ];

  // ===== MONTHLY ROLLUP =====
  const monthMap = {};

  for (const pd of last12Weeks) {
    const date = new Date(pd.epochMs);
    const monthKey = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;

    if (!monthMap[monthKey]) {
      monthMap[monthKey] = [];
    }
    monthMap[monthKey].push(pd);
  }

  const monthlyData = Object.keys(monthMap).sort().map(monthKey => {
    const monthPages = monthMap[monthKey];
    const [year, month] = monthKey.split('-');
    const monthName = new Date(year, parseInt(month) - 1, 1).toLocaleString('en-US', { month: 'long', year: 'numeric' });

    const monthWeights = monthPages.map(pd => toNumber(pd.page.value && pd.page.value("weight"))).filter(v => v != null);
    const monthStartWeight = monthWeights.length > 0 ? monthWeights[0] : null;
    const monthEndWeight = monthWeights.length > 0 ? monthWeights[monthWeights.length - 1] : null;
    const monthLoss = monthStartWeight && monthEndWeight ? monthStartWeight - monthEndWeight : null;

    const monthSteps = monthPages.map(pd => toNumber(pd.page.value && pd.page.value("steps"))).filter(v => v != null);
    const avgMonthSteps = mean(monthSteps);

    return {
      month: monthName,
      loss: monthLoss,
      avgSteps: avgMonthSteps,
      days: monthPages.length
    };
  }).reverse();

  // Calculate monthly extremes for highlighting
  const validMonthlyLoss = monthlyData.map(m => m.loss).filter(v => v != null);
  const bestMonthLoss = validMonthlyLoss.length > 0 ? Math.max(...validMonthlyLoss) : null;
  const worstMonthLoss = validMonthlyLoss.length > 0 ? Math.min(...validMonthlyLoss) : null;

  const validMonthlySteps = monthlyData.map(m => m.avgSteps).filter(v => v != null);
  const bestMonthSteps = validMonthlySteps.length > 0 ? Math.max(...validMonthlySteps) : null;
  const worstMonthSteps = validMonthlySteps.length > 0 ? Math.min(...validMonthlySteps) : null;

  const monthlyGoal = 5.0; // lbs per month

  const monthlyCols = [
    {
      id: "loss", title: "Weight Change", value: r => {
        if (r.loss == null) return "—";

        const isLoss = r.loss > 0;
        const isGain = r.loss < 0;

        if (!isLoss && !isGain) {
          return "No change";
        }

        const lbs = Math.abs(r.loss);
        const kg = Math.abs(r.loss * 0.453592);
        const label = isLoss ? "lost" : "gained";

        // Keep some of your old highlighting logic:
        const meetsGoal = isLoss && r.loss >= monthlyGoal * 0.9;
        const isBestMonth = r.loss === bestMonthLoss;
        const isWorstMonth = r.loss === worstMonthLoss;

        let className = "";
        if (isGain || isWorstMonth) {
          className = "bp-high";       // red
        } else if (meetsGoal || isBestMonth) {
          className = "bp-low";        // green
        }

        return (
          <span className={className}>
            {lbs.toFixed(1)} lbs {label} ({kg.toFixed(1)} kg)
          </span>
        );
      }
    },

    {
      id: "avgSteps", title: "Avg Steps/Day", value: r => {
        if (r.avgSteps == null) return "—";
        const isBest = r.avgSteps === bestMonthSteps;
        const isWorst = r.avgSteps === worstMonthSteps;
        const className = isBest ? "bp-low" : isWorst ? "bp-high" : "";
        return <span className={className + " num"}>{r.avgSteps.toFixed(0)}</span>;
      }
    },
    { id: "days", title: "Days Tracked", value: r => r.days }
  ];

  return (
    <div>
      <h3>12-Week Summary</h3>
      <dc.Table columns={summaryCols} rows={summaryRows} />

      <h3>Weekly Weight & Activity Trends (12 Weeks)</h3>
      <dc.Table columns={weeklyCols} rows={weeklyRows} />

      <h3>Weekly Health Indicators</h3>
      <dc.Table columns={healthCols} rows={healthRows} />

      <h3>Monthly Summary</h3>
      <dc.Table columns={monthlyCols} rows={monthlyData} />
    </div>
  );
}
```
