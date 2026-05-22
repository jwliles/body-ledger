---
age:
  - 38.1.17
age_unix: 1203432290
authors:
  - jwl
title: trends_dashboard
timestamp: 1760668927580
date_created: 2025-10-21T16:30:00
date_updated: 2025-10-21T16:30:00
hash: 0c9111256cbed168ea37696122f11d34121be4750080940b9bfb80fd50cb7dda
id: c066f580-2361-4773-9498-3792600dca66
tags:
  - dashboard
  - trends
  - health_tracking
  - rolling_averages
---

# trends_dashboard

## What this dashboard shows

### Purpose

This dashboard tracks **trends and changes over time** in your health metrics, helping you spot improvements or concerning patterns that might be missed in daily snapshots.

### Metrics Tracked

1. **Blood Pressure Trends**: Rolling averages (7, 14, 30-day) for systolic, diastolic, and pulse
2. **Pulse Pressure**: Systolic - Diastolic (indicator of arterial stiffness)
3. **BP Variability**: Day-to-day variation (high variability = higher cardiovascular risk)
4. **Weight Loss Progress**: Rate of change and progress toward goals
5. **Medication Timing Consistency**: How consistent your dosing times are
6. **Sleep Efficiency**: Sleep duration ÷ Time in bed
7. **Time in Target Range**: Percentage of readings within healthy BP ranges

### How to Interpret

- **Rolling Averages**: Smooth out daily fluctuations to reveal true trends
- **Pulse Pressure**: Normal is 40-60 mmHg; >60 may indicate arterial stiffness
- **BP Variability**: Lower is better; high variability is an independent risk factor
- **Med Timing Consistency**: Smaller standard deviation = more consistent timing
- **Sleep Efficiency**: Target >85%; <85% may indicate sleep issues
- **Time in Target**: Track what % of your readings are where your doctor wants them

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

const mean = arr => {
    const valid = arr.filter(v => v != null && !isNaN(v));
    return valid.length ? valid.reduce((a, b) => a + b, 0) / valid.length : null;
};

const stdDev = arr => {
    const valid = arr.filter(v => v != null && !isNaN(v));
    if (valid.length < 2) return null;
    const avg = mean(valid);
    const squaredDiffs = valid.map(v => Math.pow(v - avg, 2));
    const variance = squaredDiffs.reduce((a, b) => a + b, 0) / valid.length;
    return Math.sqrt(variance);
};

const num = (v, decimals = 1) => {
    if (v == null || isNaN(v)) return "—";
    return <span className="num">{v.toFixed(decimals)}</span>;
};

const pct = v => {
    if (v == null || isNaN(v)) return "—";
    return <span className="num">{v.toFixed(1)}%</span>;
};

const weight = (lbs, decimals = 1) => {
    if (lbs == null || isNaN(lbs)) return "—";
    const kg = lbs * 0.453592;
    return <span className="num">{lbs.toFixed(decimals)} lbs ({kg.toFixed(1)} kg)</span>;
};

const weightRate = (lbsPerWeek) => {
    if (lbsPerWeek == null || isNaN(lbsPerWeek)) return "—";
    const kgPerWeek = lbsPerWeek * 0.453592;
    return <span className="num">{lbsPerWeek.toFixed(2)} lbs/week ({kgPerWeek.toFixed(2)} kg/week)</span>;
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

    // Sort pages by date (using the date extracted from filename, not creation time)
    const pagesWithDates = pages.map(p => {
        const dateStr = pageDateYMD(p);
        const epochMs = dateStr && dateStr !== "—" ? new Date(dateStr).getTime() : pageEpochMs(p);
        return {
            page: p,
            date: dateStr,
            epochMs: epochMs
        };
    }).filter(pd => pd.epochMs != null && !isNaN(pd.epochMs)).sort((a, b) => a.epochMs - b.epochMs);

    // ===== BLOOD PRESSURE TRENDS =====
    const bpData = pagesWithDates.map(pd => ({
        date: pd.date,
        epochMs: pd.epochMs,
        amSys: toNumber(pd.page.value && pd.page.value("am_sys")),
        amDia: toNumber(pd.page.value && pd.page.value("am_dia")),
        amPulse: toNumber(pd.page.value && pd.page.value("am_hr")),
        pmSys: toNumber(pd.page.value && pd.page.value("pm_sys")),
        pmDia: toNumber(pd.page.value && pd.page.value("pm_dia")),
        pmPulse: toNumber(pd.page.value && pd.page.value("pm_hr"))
    }));

    const rollingAvg = (data, days) => {
        const cutoff = Date.now() - days * 24 * 60 * 60 * 1000;
        const recent = data.filter(d => d.epochMs >= cutoff);

        const allSys = recent.flatMap(d => [d.amSys, d.pmSys]).filter(v => v != null);
        const allDia = recent.flatMap(d => [d.amDia, d.pmDia]).filter(v => v != null);
        const allPulse = recent.flatMap(d => [d.amPulse, d.pmPulse]).filter(v => v != null);

        return {
            avgSys: mean(allSys),
            avgDia: mean(allDia),
            avgPulse: mean(allPulse),
            count: Math.min(allSys.length, allDia.length)
        };
    };

    const bp7d = rollingAvg(bpData, 7);
    const bp14d = rollingAvg(bpData, 14);
    const bp30d = rollingAvg(bpData, 30);

    const bpTrendRows = [
        {
            period: "7-Day Average",
            sys: bp7d.avgSys,
            dia: bp7d.avgDia,
            pulse: bp7d.avgPulse,
            readings: bp7d.count
        },
        {
            period: "14-Day Average",
            sys: bp14d.avgSys,
            dia: bp14d.avgDia,
            pulse: bp14d.avgPulse,
            readings: bp14d.count
        },
        {
            period: "30-Day Average",
            sys: bp30d.avgSys,
            dia: bp30d.avgDia,
            pulse: bp30d.avgPulse,
            readings: bp30d.count
        }
    ];

    const bpTrendCols = [
        { id: "period", title: "Period", value: r => r.period },
        { id: "sys", title: "Average Systolic (mmHg)", value: r => num(r.sys) },
        { id: "dia", title: "Average Diastolic (mmHg)", value: r => num(r.dia) },
        { id: "pulse", title: "Average Pulse (bpm)", value: r => num(r.pulse) },
        { id: "readings", title: "Readings", value: r => r.readings }
    ];

    // ===== PULSE PRESSURE =====
    const pulsePressureData = bpData.flatMap(d => {
        const results = [];
        if (d.amSys != null && d.amDia != null) {
            results.push({ date: d.date, time: "Wake", pp: d.amSys - d.amDia });
        }
        if (d.pmSys != null && d.pmDia != null) {
            results.push({ date: d.date, time: "Sleep", pp: d.pmSys - d.pmDia });
        }
        return results;
    });

    const recentPP = pulsePressureData.slice(-30);
    const avgPP = mean(recentPP.map(d => d.pp));
    const minPP = recentPP.length ? Math.min(...recentPP.map(d => d.pp)) : null;
    const maxPP = recentPP.length ? Math.max(...recentPP.map(d => d.pp)) : null;

    const ppRows = [{
        metric: "Pulse Pressure (last 30 days)",
        avg: avgPP,
        min: minPP,
        max: maxPP,
        note: avgPP && avgPP > 60 ? "⚠️ Elevated" : avgPP && avgPP < 40 ? "⚠️ Low" : "✓ Normal"
    }];

    const ppCols = [
        { id: "metric", title: "Metric", value: r => r.metric },
        { id: "avg", title: "Average (mmHg)", value: r => num(r.avg) },
        { id: "min", title: "Min (mmHg)", value: r => num(r.min, 0) },
        { id: "max", title: "Max (mmHg)", value: r => num(r.max, 0) },
        { id: "note", title: "Status", value: r => r.note }
    ];

    // ===== BP VARIABILITY =====
    const last30Sys = bpData.filter(d => d.epochMs >= Date.now() - 30 * 24 * 60 * 60 * 1000)
        .flatMap(d => [d.amSys, d.pmSys]).filter(v => v != null);
    const last30Dia = bpData.filter(d => d.epochMs >= Date.now() - 30 * 24 * 60 * 60 * 1000)
        .flatMap(d => [d.amDia, d.pmDia]).filter(v => v != null);

    const sysSD = stdDev(last30Sys);
    const diaSD = stdDev(last30Dia);

    const variabilityRows = [{
        metric: "BP Variability (last 30 days)",
        sysSD: sysSD,
        diaSD: diaSD,
        note: sysSD && sysSD > 15 ? "⚠️ High variability" : "✓ Normal"
    }];

    const variabilityCols = [
        { id: "metric", title: "Metric", value: r => r.metric },
        { id: "sysSD", title: "Systolic Standard Deviation (mmHg)", value: r => num(r.sysSD) },
        { id: "diaSD", title: "Diastolic Standard Deviation (mmHg)", value: r => num(r.diaSD) },
        { id: "note", title: "Status", value: r => r.note }
    ];

    // ===== WEIGHT LOSS PROGRESS =====
    const weightData = pagesWithDates.map(pd => ({
        date: pd.date,
        epochMs: pd.epochMs,
        weight: toNumber(pd.page.value && pd.page.value("weight"))
    })).filter(d => d.weight != null);

    const startWeight = weightData.length > 0 ? weightData[0].weight : null;
    const currentWeight = weightData.length > 0 ? weightData[weightData.length - 1].weight : null;
    const totalLoss = startWeight && currentWeight ? startWeight - currentWeight : null;

    // Calculate weight change rate (lbs per week)
    // Try last 60 days first, fall back to all data if recent shows gain/plateau
    let weeklyRate = null;
    const last60Days = Date.now() - 60 * 24 * 60 * 60 * 1000;
    const recentWeights = weightData.filter(d => d.epochMs >= last60Days);

    if (recentWeights.length >= 2) {
        const first = recentWeights[0];
        const last = recentWeights[recentWeights.length - 1];
        const daysDiff = (last.epochMs - first.epochMs) / (24 * 60 * 60 * 1000);
        const weeksDiff = daysDiff / 7;
        const weightDiff = first.weight - last.weight;
        const recentRate = weeksDiff > 0 ? weightDiff / weeksDiff : null;

        // Use recent rate if it shows loss, otherwise use all-time rate
        if (recentRate && recentRate > 0) {
            weeklyRate = recentRate;
        } else if (weightData.length >= 2) {
            // Fall back to all-time rate
            const firstEver = weightData[0];
            const lastEver = weightData[weightData.length - 1];
            const allDaysDiff = (lastEver.epochMs - firstEver.epochMs) / (24 * 60 * 60 * 1000);
            const allWeeksDiff = allDaysDiff / 7;
            const allWeightDiff = firstEver.weight - lastEver.weight;
            weeklyRate = allWeeksDiff > 0 && allWeightDiff > 0 ? allWeightDiff / allWeeksDiff : null;
        }
    } else if (weightData.length >= 2) {
        // Not enough recent data, use all-time rate
        const firstEver = weightData[0];
        const lastEver = weightData[weightData.length - 1];
        const allDaysDiff = (lastEver.epochMs - firstEver.epochMs) / (24 * 60 * 60 * 1000);
        const allWeeksDiff = allDaysDiff / 7;
        const allWeightDiff = firstEver.weight - lastEver.weight;
        weeklyRate = allWeeksDiff > 0 && allWeightDiff > 0 ? allWeightDiff / allWeeksDiff : null;
    }

    const goalWeight = 210;
    const remaining = currentWeight ? currentWeight - goalWeight : null;
    const monthsToGoal = weeklyRate && weeklyRate > 0 && remaining && remaining > 0 ? (remaining / (weeklyRate * 4.33)) : null;

    const weightRows = [{
        metric: "Weight Progress",
        start: startWeight,
        current: currentWeight,
        loss: totalLoss,
        rate: weeklyRate,
        remaining: remaining,
        eta: monthsToGoal
    }];

    const weightCols = [
        { id: "metric", title: "Metric", value: r => r.metric },
        { id: "start", title: "Start Weight", value: r => weight(r.start) },
        { id: "current", title: "Current", value: r => weight(r.current) },
        { id: "loss", title: "Total Loss", value: r => weight(r.loss) },
        { id: "rate", title: "Rate", value: r => weightRate(r.rate) },
        { id: "remaining", title: "To Goal 210 lbs", value: r => weight(r.remaining) },
        { id: "eta", title: "ETA (months)", value: r => num(r.eta) }
    ];

    // ===== MEDICATION TIMING CONSISTENCY =====

    // Helper to safely get day of week from YYYY-MM-DD string
    const getDayType = (dateStr) => {
        if (!dateStr) return null;
        const parts = dateStr.split('-').map(Number);
        // Construct date in local time to avoid UTC shifts
        const d = new Date(parts[0], parts[1] - 1, parts[2]);
        const day = d.getDay(); // 0 = Sun, 6 = Sat
        return (day === 0 || day === 6) ? 'weekend' : 'weekday';
    };

    const minutesToHHMM = (m) => {
        if (m == null || !Number.isFinite(m)) return "—";
        m = Math.round(m);
        const hh = Math.floor(m / 60) % 24;
        const mm = m % 60;
        return `${String(hh).padStart(2, "0")}:${String(mm).padStart(2, "0")}`;
    };

    // 1. Process all raw data points first
    const medDataPoints = pagesWithDates.map(pd => ({
        am: isoToMinutes(pd.page.value && pd.page.value("am_meds")),
        pm: isoToMinutes(pd.page.value && pd.page.value("pm_meds")),
        type: getDayType(pd.date)
    }));

    // 2. Filter into cohorts
    const medCohorts = {
        overall: medDataPoints,
        weekday: medDataPoints.filter(d => d.type === 'weekday'),
        weekend: medDataPoints.filter(d => d.type === 'weekend')
    };

    // 3. Calculation function
    const calcMedStats = (dataset) => {
        const amTimes = dataset.map(d => d.am).filter(v => v != null);
        const pmTimes = dataset.map(d => d.pm).filter(v => v != null);

        const amAvg = mean(amTimes);
        const amSD = stdDev(amTimes);
        const pmAvg = mean(pmTimes);
        const pmSD = stdDev(pmTimes);

        return [
            {
                schedule: "Wake Meds",
                avgTime: minutesToHHMM(amAvg),
                consistency: amSD,
                count: amTimes.length,
                note: amSD && amSD < 30 ? "✓ Consistent" : amSD && amSD < 60 ? "⚠️ Moderate" : "⚠️ Variable"
            },
            {
                schedule: "Sleep Meds",
                avgTime: minutesToHHMM(pmAvg),
                consistency: pmSD,
                count: pmTimes.length,
                note: pmSD && pmSD < 30 ? "✓ Consistent" : pmSD && pmSD < 60 ? "⚠️ Moderate" : "⚠️ Variable"
            }
        ];
    };

    const consistencyRows = calcMedStats(medCohorts.overall);
    const consistencyRowsWeekday = calcMedStats(medCohorts.weekday);
    const consistencyRowsWeekend = calcMedStats(medCohorts.weekend);

    const consistencyCols = [
        { id: "schedule", title: "Schedule", value: r => r.schedule },
        { id: "avgTime", title: "Average Time", value: r => r.avgTime },
        { id: "consistency", title: "Std Dev (min)", value: r => num(r.consistency) },
        { id: "count", title: "Count", value: r => r.count },
        { id: "note", title: "Status", value: r => r.note }
    ];

    // ===== SLEEP EFFICIENCY =====
    const sleepData = pagesWithDates.map(pd => {
        const bedtime = isoToMinutes(pd.page.value && pd.page.value("bedtime"));
        const wakeTime = isoToMinutes(pd.page.value && pd.page.value("wake_time"));
        const sleepMins = toNumber(pd.page.value && pd.page.value("sleep"));

        if (bedtime != null && wakeTime != null && sleepMins != null) {
            const timeInBed = wakeTime >= bedtime ? wakeTime - bedtime : (wakeTime + 24 * 60 - bedtime);
            const efficiency = timeInBed > 0 ? (sleepMins / timeInBed) * 100 : null;
            return { date: pd.date, efficiency: efficiency };
        }
        return null;
    }).filter(v => v != null);

    const recentSleep = sleepData.slice(-30);
    const avgEfficiency = mean(recentSleep.map(d => d.efficiency));
    const minEfficiency = recentSleep.length ? Math.min(...recentSleep.map(d => d.efficiency)) : null;
    const maxEfficiency = recentSleep.length ? Math.max(...recentSleep.map(d => d.efficiency)) : null;

    const sleepRows = [{
        metric: "Sleep Efficiency (last 30 days)",
        avg: avgEfficiency,
        min: minEfficiency,
        max: maxEfficiency,
        note: avgEfficiency && avgEfficiency >= 85 ? "✓ Good" : avgEfficiency && avgEfficiency >= 75 ? "⚠️ Fair" : "⚠️ Poor"
    }];

    const sleepCols = [
        { id: "metric", title: "Metric", value: r => r.metric },
        { id: "avg", title: "Average Efficiency", value: r => pct(r.avg) },
        { id: "min", title: "Min", value: r => pct(r.min) },
        { id: "max", title: "Max", value: r => pct(r.max) },
        { id: "note", title: "Status", value: r => r.note }
    ];

    // ===== TIME IN TARGET RANGE =====
    // Target: Systolic 120-140, Diastolic 70-90 (adjust these based on your doctor's recommendations)
    const TARGET_SYS_LOW = 120;
    const TARGET_SYS_HIGH = 140;
    const TARGET_DIA_LOW = 70;
    const TARGET_DIA_HIGH = 90;

    const allReadings = bpData.flatMap(d => {
        const results = [];
        if (d.amSys != null && d.amDia != null) {
            results.push({ sys: d.amSys, dia: d.amDia });
        }
        if (d.pmSys != null && d.pmDia != null) {
            results.push({ sys: d.pmSys, dia: d.pmDia });
        }
        return results;
    });

    const recent30Readings = allReadings.slice(-60); // last 30 days = ~60 readings
    const inTargetSys = recent30Readings.filter(r => r.sys >= TARGET_SYS_LOW && r.sys <= TARGET_SYS_HIGH).length;
    const inTargetDia = recent30Readings.filter(r => r.dia >= TARGET_DIA_LOW && r.dia <= TARGET_DIA_HIGH).length;
    const inTargetBoth = recent30Readings.filter(r =>
        r.sys >= TARGET_SYS_LOW && r.sys <= TARGET_SYS_HIGH &&
        r.dia >= TARGET_DIA_LOW && r.dia <= TARGET_DIA_HIGH
    ).length;

    const pctInTargetSys = recent30Readings.length ? (inTargetSys / recent30Readings.length) * 100 : null;
    const pctInTargetDia = recent30Readings.length ? (inTargetDia / recent30Readings.length) * 100 : null;
    const pctInTargetBoth = recent30Readings.length ? (inTargetBoth / recent30Readings.length) * 100 : null;

    const targetRows = [
        {
            metric: "Systolic in Target (120-140)",
            pct: pctInTargetSys,
            count: inTargetSys,
            total: recent30Readings.length
        },
        {
            metric: "Diastolic in Target (70-90)",
            pct: pctInTargetDia,
            count: inTargetDia,
            total: recent30Readings.length
        },
        {
            metric: "Both in Target",
            pct: pctInTargetBoth,
            count: inTargetBoth,
            total: recent30Readings.length
        }
    ];

    const targetCols = [
        { id: "metric", title: "Metric", value: r => r.metric },
        { id: "pct", title: "% in Target", value: r => pct(r.pct) },
        { id: "count", title: "Count", value: r => `${r.count}/${r.total}` }
    ];

    return (
        <div>
            <h3>Blood Pressure Rolling Averages</h3>
            <dc.Table columns={bpTrendCols} rows={bpTrendRows} />

            <h3>Pulse Pressure Analysis</h3>
            <dc.Table columns={ppCols} rows={ppRows} />

            <h3>Blood Pressure Variability</h3>
            <dc.Table columns={variabilityCols} rows={variabilityRows} />

            <h3>Weight Loss Progress</h3>
            <dc.Table columns={weightCols} rows={weightRows} />

            <h3>Medication Timing Consistency</h3>

            <h4>1. Overall Performance</h4>
            <dc.Table columns={consistencyCols} rows={consistencyRows} />

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '20px', marginTop: '20px' }}>
                <div>
                    <h4>2. Weekdays (Mon-Fri)</h4>
                    <dc.Table columns={consistencyCols} rows={consistencyRowsWeekday} />
                </div>
                <div>
                    <h4>3. Weekends (Sat-Sun)</h4>
                    <dc.Table columns={consistencyCols} rows={consistencyRowsWeekend} />
                </div>
            </div>

            <h3>Sleep Efficiency</h3>
            <dc.Table columns={sleepCols} rows={sleepRows} />

            <h3>Time in Target BP Range (Last 30 Days)</h3>
            <dc.Table columns={targetCols} rows={targetRows} />
        </div>
    );
}
```
