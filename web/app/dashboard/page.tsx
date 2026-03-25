"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";

const API = process.env.NEXT_PUBLIC_API_URL;

type Medication = {
  id: number;
  name: string;
  strength: string;
  is_active: boolean;
};

type HealthEvent = {
  id: number;
  recorded_at: string;
  payload: {
    medication_id: number;
    dose_mg: number;
    dose_type: string;
  };
};

function timeAgo(dateStr: string): string {
  const diffMs = Date.now() - new Date(dateStr).getTime();
  const diffMins = Math.floor(diffMs / 60000);
  if (diffMins < 1) return "just now";
  if (diffMins < 60) return `${diffMins}m ago`;
  const diffHrs = Math.floor(diffMins / 60);
  if (diffHrs < 24) return `${diffHrs}h ago`;
  const diffDays = Math.floor(diffHrs / 24);
  return `${diffDays}d ago`;
}

function formatTime(d: Date): string {
  return d.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", second: "2-digit" });
}

function formatDate(d: Date): string {
  return d.toLocaleDateString([], { weekday: "long", month: "long", day: "numeric" });
}

export default function DashboardPage() {
  const router = useRouter();
  const [username, setUsername] = useState("");
  const [now, setNow] = useState(new Date());
  const [medications, setMedications] = useState<Medication[]>([]);
  const [lastDoses, setLastDoses] = useState<Record<number, { dose_mg: number; recorded_at: string }>>({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const token = localStorage.getItem("device_token");
    if (!token) {
      router.replace("/");
      return;
    }
    setUsername(localStorage.getItem("username") ?? "");

    async function fetchData() {
      const token = localStorage.getItem("device_token")!;
      const headers = { Authorization: `Bearer ${token}` };

      try {
        const [medsRes, eventsRes] = await Promise.all([
          fetch(`${API}/api/v1/medications`, { headers }),
          fetch(`${API}/api/v1/health_events?metric_type=medication_dose`, { headers }),
        ]);

        if (!medsRes.ok || !eventsRes.ok) {
          if (medsRes.status === 401 || eventsRes.status === 401) {
            localStorage.clear();
            router.replace("/");
            return;
          }
          setError("Failed to load data");
          return;
        }

        const meds: Medication[] = await medsRes.json();
        const events: HealthEvent[] = await eventsRes.json();

        const doses: Record<number, { dose_mg: number; recorded_at: string }> = {};
        for (const event of events) {
          const { medication_id, dose_mg } = event.payload;
          const existing = doses[medication_id];
          if (!existing || new Date(event.recorded_at) > new Date(existing.recorded_at)) {
            doses[medication_id] = { dose_mg, recorded_at: event.recorded_at };
          }
        }

        setMedications(meds.filter((m) => m.is_active));
        setLastDoses(doses);
      } catch {
        setError("Could not reach the server");
      } finally {
        setLoading(false);
      }
    }

    fetchData();

    const clock = setInterval(() => setNow(new Date()), 1000);
    return () => clearInterval(clock);
  }, [router]);

  function signOut() {
    localStorage.removeItem("device_token");
    localStorage.removeItem("device_id");
    localStorage.removeItem("username");
    router.replace("/");
  }

  return (
    <div className="min-h-screen bg-ctp-crust flex flex-col">
      {/* Header */}
      <header className="flex items-center justify-between px-6 py-4 border-b border-ctp-surface0">
        <div>
          <h1 className="text-xl font-semibold text-ctp-text">body ledger</h1>
          <p className="text-sm text-ctp-subtext0">Hello, {username}</p>
        </div>
        <div className="text-right">
          <p className="text-sm text-ctp-subtext1">{formatDate(now)}</p>
          <p className="text-lg font-mono text-ctp-text">{formatTime(now)}</p>
        </div>
      </header>

      {/* Tab bar */}
      <div className="px-6 pt-4">
        <div className="inline-flex rounded-lg bg-ctp-surface0 p-1">
          <button className="rounded-md px-4 py-1.5 text-sm font-medium bg-ctp-base text-ctp-text shadow-sm">
            Adherence
          </button>
        </div>
      </div>

      {/* Main content */}
      <main className="flex-1 px-6 py-4">
        <h2 className="text-base font-medium text-ctp-subtext1 mb-3">Medication Adherence</h2>

        {loading && (
          <p className="text-sm text-ctp-overlay0">Loading…</p>
        )}

        {error && (
          <p className="text-sm text-ctp-red">{error}</p>
        )}

        {!loading && !error && (
          <div className="rounded-xl border border-ctp-surface0 overflow-hidden">
            <table className="w-full text-sm">
              <thead>
                <tr className="bg-ctp-surface0 text-ctp-subtext1">
                  <th className="text-left px-4 py-2.5 font-medium">Medication</th>
                  <th className="text-left px-4 py-2.5 font-medium">Last dose</th>
                  <th className="text-left px-4 py-2.5 font-medium">Time since</th>
                </tr>
              </thead>
              <tbody>
                {medications.length === 0 && (
                  <tr>
                    <td colSpan={3} className="px-4 py-4 text-center text-ctp-overlay0">
                      No active medications
                    </td>
                  </tr>
                )}
                {medications.map((med, i) => {
                  const dose = lastDoses[med.id];
                  return (
                    <tr
                      key={med.id}
                      className={i % 2 === 0 ? "bg-ctp-base" : "bg-ctp-mantle"}
                    >
                      <td className="px-4 py-3 text-ctp-text">{med.name}</td>
                      <td className="px-4 py-3 text-ctp-subtext0">
                        {dose ? `${dose.dose_mg} mg` : "—"}
                      </td>
                      <td className="px-4 py-3 text-ctp-subtext0">
                        {dose ? timeAgo(dose.recorded_at) : "never"}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </main>

      {/* Footer */}
      <footer className="px-6 py-4 flex justify-end border-t border-ctp-surface0">
        <button
          onClick={signOut}
          className="text-sm text-ctp-subtext1 hover:text-ctp-red transition cursor-pointer"
        >
          Sign out
        </button>
      </footer>
    </div>
  );
}
