"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";

const API = process.env.NEXT_PUBLIC_API_URL;

type ReportValue = string | number | boolean | null | { value: string | number | null; source?: string };
type ReportRow = Record<string, ReportValue>;
type ReportSection = {
  id: string;
  title: string;
  columns: string[];
  rows: ReportRow[];
};
type Report = {
  id: string;
  title: string;
  explanation: string;
  period?: Record<string, string>;
  sections: ReportSection[];
};

const REPORTS = [
  { id: "weekly_summary", label: "Weekly Summary" },
  { id: "daily_metrics_dashboard", label: "Daily Metrics" },
  { id: "sleep_dashboard", label: "Sleep Dashboard" },
  { id: "meds_dashboard", label: "Meds Dashboard" },
  { id: "bp_readings", label: "BP Readings" },
  { id: "trends_dashboard", label: "Trends Dashboard" },
  { id: "correlations_dashboard", label: "Correlations" },
  { id: "dietitian_report", label: "Dietitian Report" },
];

function todayInputValue(): string {
  return new Date().toISOString().slice(0, 10);
}

function displayLabel(value: string): string {
  return value
    .split("_")
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(" ");
}

function displayValue(value: ReportValue): { text: string; source?: string } {
  if (value === null || value === undefined || value === "") return { text: "-" };
  if (typeof value === "object" && "value" in value) {
    return {
      text: value.value === null || value.value === undefined || value.value === "" ? "-" : String(value.value),
      source: value.source,
    };
  }
  return { text: String(value) };
}

export default function ReportsPage() {
  const router = useRouter();
  const [reportId, setReportId] = useState(REPORTS[0].id);
  const [endDate, setEndDate] = useState(todayInputValue());
  const [report, setReport] = useState<Report | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const reportTitle = useMemo(
    () => REPORTS.find((item) => item.id === reportId)?.label ?? "Report",
    [reportId],
  );

  const fetchReport = useCallback(async () => {
    const token = localStorage.getItem("device_token");
    if (!token) {
      router.replace("/");
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const params = new URLSearchParams({ end_date: endDate });
      const res = await fetch(`${API}/api/v1/reports/${reportId}?${params.toString()}`, {
        headers: { Authorization: `Bearer ${token}` },
      });

      if (res.status === 401) {
        localStorage.clear();
        router.replace("/");
        return;
      }

      if (!res.ok) {
        setError("Failed to load report");
        return;
      }

      setReport(await res.json());
    } catch {
      setError("Could not reach the server");
    } finally {
      setLoading(false);
    }
  }, [endDate, reportId, router]);

  useEffect(() => {
    fetchReport();
  }, [fetchReport]);

  return (
    <div className="min-h-screen bg-ctp-crust text-ctp-text">
      <header className="border-b border-ctp-surface0 px-4 py-4 sm:px-6">
        <div className="mx-auto flex max-w-7xl flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h1 className="text-xl font-semibold">Reports</h1>
            <p className="text-sm text-ctp-subtext0">Rails projections generated from Body Ledger records.</p>
          </div>
          <Link
            href="/dashboard"
            className="w-fit rounded-lg border border-ctp-surface1 px-4 py-2 text-sm font-medium text-ctp-text transition hover:border-ctp-blue"
          >
            Dashboard
          </Link>
        </div>
      </header>

      <main className="px-3 py-4 sm:px-6 sm:py-5">
        <div className="mx-auto flex max-w-7xl flex-col gap-5">
          <section className="rounded-xl border border-ctp-surface0 bg-ctp-base p-4">
            <div className="grid gap-3 sm:grid-cols-[1fr_180px]">
              <select
                aria-label="Report"
                value={reportId}
                onChange={(event) => setReportId(event.target.value)}
                className="rounded-lg bg-ctp-surface1 px-3 py-2 text-sm text-ctp-text outline-none focus:ring-2 focus:ring-ctp-blue"
              >
                {REPORTS.map((item) => (
                  <option key={item.id} value={item.id}>
                    {item.label}
                  </option>
                ))}
              </select>
              <input
                aria-label="End date"
                type="date"
                value={endDate}
                onChange={(event) => setEndDate(event.target.value)}
                className="rounded-lg bg-ctp-surface1 px-3 py-2 text-sm text-ctp-text outline-none focus:ring-2 focus:ring-ctp-blue"
              />
            </div>
          </section>

          {loading && <p className="text-sm text-ctp-overlay0">Loading {reportTitle}...</p>}
          {error && <p className="text-sm text-ctp-red">{error}</p>}

          {report && !loading && (
            <>
              <section className="rounded-xl border border-ctp-surface0 bg-ctp-base p-4">
                <h2 className="text-lg font-medium">{report.title}</h2>
                <p className="mt-2 max-w-4xl text-sm leading-6 text-ctp-subtext0">{report.explanation}</p>
                {report.period && (
                  <dl className="mt-4 grid gap-2 text-sm sm:grid-cols-4">
                    {Object.entries(report.period).map(([key, value]) => (
                      <div key={key}>
                        <dt className="text-xs uppercase text-ctp-overlay0">{displayLabel(key)}</dt>
                        <dd className="text-ctp-subtext1">{value}</dd>
                      </div>
                    ))}
                  </dl>
                )}
              </section>

              {report.sections.map((section) => (
                <section key={section.id} className="rounded-xl border border-ctp-surface0 bg-ctp-base">
                  <div className="border-b border-ctp-surface0 px-4 py-3">
                    <h3 className="text-base font-medium">{section.title}</h3>
                  </div>
                  {section.rows.length === 0 ? (
                    <p className="px-4 py-6 text-center text-sm text-ctp-overlay0">No data for this period.</p>
                  ) : (
                    <div className="overflow-x-auto">
                      <table className="w-full min-w-[720px] text-sm">
                        <thead className="bg-ctp-surface0 text-ctp-subtext1">
                          <tr>
                            {section.columns.map((column) => (
                              <th key={column} className="px-4 py-2.5 text-left font-medium">
                                {displayLabel(column)}
                              </th>
                            ))}
                          </tr>
                        </thead>
                        <tbody>
                          {section.rows.map((row, rowIndex) => (
                            <tr key={rowIndex} className={rowIndex % 2 === 0 ? "bg-ctp-base" : "bg-ctp-mantle"}>
                              {section.columns.map((column) => {
                                const rendered = displayValue(row[column]);
                                return (
                                  <td key={column} className="px-4 py-3 text-ctp-subtext0">
                                    <span className="text-ctp-text">{rendered.text}</span>
                                    {rendered.source && (
                                      <span className="ml-2 text-xs text-ctp-overlay0">{rendered.source}</span>
                                    )}
                                  </td>
                                );
                              })}
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  )}
                </section>
              ))}
            </>
          )}
        </div>
      </main>
    </div>
  );
}
