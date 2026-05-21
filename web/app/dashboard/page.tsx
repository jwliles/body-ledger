"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";

const API = process.env.NEXT_PUBLIC_API_URL;

type DoseType = "scheduled" | "prn" | "missed" | "reconciliation";

type Medication = {
  id: number;
  name: string;
  strength: string;
  is_prn: boolean;
  scheduled_times: string[] | null;
  pill_size_mg: string | number | null;
  is_active: boolean;
};

type HealthEvent = {
  id: number;
  recorded_at: string;
  payload: {
    medication_id: number;
    dose_mg: string | number;
    dose_type: DoseType;
  } | null;
};

type MedicationForm = {
  name: string;
  strength: string;
  isPrn: boolean;
  scheduledTimes: string;
  pillSizeMg: string;
};

type DoseForm = {
  doseMg: string;
  doseType: DoseType;
};

const initialMedicationForm: MedicationForm = {
  name: "",
  strength: "",
  isPrn: false,
  scheduledTimes: "08:00",
  pillSizeMg: "",
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

function formatDose(value: string | number): string {
  const dose = Number(value);
  return Number.isFinite(dose) ? `${dose} mg` : `${value} mg`;
}

function parseScheduledTimes(value: string): string[] {
  return value
    .split(",")
    .map((part) => part.trim())
    .filter(Boolean);
}

function medicationDefaultDose(medication: Medication): string {
  if (medication.pill_size_mg) return String(medication.pill_size_mg);

  const match = medication.strength.match(/(\d+(?:\.\d+)?)\s*mg/i);
  return match?.[1] ?? "";
}

function eventMedicationId(event: HealthEvent): number | null {
  return event.payload?.medication_id ?? null;
}

async function parseApiError(response: Response): Promise<string> {
  try {
    const data = await response.json();
    if (Array.isArray(data.errors)) return data.errors.join(", ");
    if (typeof data.error === "string") return data.error;
  } catch {
    // Ignore JSON parse failures and fall back to status text.
  }

  return response.statusText || "Request failed";
}

export default function DashboardPage() {
  const router = useRouter();
  const [username, setUsername] = useState("");
  const [now, setNow] = useState(new Date());
  const [medications, setMedications] = useState<Medication[]>([]);
  const [events, setEvents] = useState<HealthEvent[]>([]);
  const [medicationForm, setMedicationForm] = useState<MedicationForm>(initialMedicationForm);
  const [doseForms, setDoseForms] = useState<Record<number, DoseForm>>({});
  const [loading, setLoading] = useState(true);
  const [savingMedication, setSavingMedication] = useState(false);
  const [savingDoseId, setSavingDoseId] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);

  const activeMedications = useMemo(
    () => medications.filter((medication) => medication.is_active),
    [medications],
  );

  const lastDoses = useMemo(() => {
    const doses: Record<number, HealthEvent> = {};

    for (const event of events) {
      const medicationId = eventMedicationId(event);
      if (!medicationId) continue;

      const existing = doses[medicationId];
      if (!existing || new Date(event.recorded_at) > new Date(existing.recorded_at)) {
        doses[medicationId] = event;
      }
    }

    return doses;
  }, [events]);

  const medicationNames = useMemo(() => {
    return Object.fromEntries(medications.map((medication) => [medication.id, medication.name]));
  }, [medications]);

  const fetchData = useCallback(async () => {
    const token = localStorage.getItem("device_token");
    if (!token) {
      router.replace("/");
      return;
    }

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
      const doseEvents: HealthEvent[] = await eventsRes.json();

      doseEvents.sort((a, b) => new Date(b.recorded_at).getTime() - new Date(a.recorded_at).getTime());
      setMedications(meds);
      setEvents(doseEvents);
      setDoseForms((currentForms) => {
        const nextForms = { ...currentForms };
        for (const medication of meds) {
          nextForms[medication.id] ??= {
            doseMg: medicationDefaultDose(medication),
            doseType: medication.is_prn ? "prn" : "scheduled",
          };
        }
        return nextForms;
      });
    } catch {
      setError("Could not reach the server");
    } finally {
      setLoading(false);
    }
  }, [router]);

  useEffect(() => {
    setUsername(localStorage.getItem("username") ?? "");
    fetchData();

    const clock = setInterval(() => setNow(new Date()), 1000);
    return () => clearInterval(clock);
  }, [fetchData]);

  function signOut() {
    localStorage.removeItem("device_token");
    localStorage.removeItem("device_id");
    localStorage.removeItem("username");
    router.replace("/");
  }

  async function createMedication(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setSavingMedication(true);

    const token = localStorage.getItem("device_token");
    if (!token) {
      router.replace("/");
      return;
    }

    const scheduledTimes = parseScheduledTimes(medicationForm.scheduledTimes);

    try {
      const res = await fetch(`${API}/api/v1/medications`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          medication: {
            name: medicationForm.name,
            strength: medicationForm.strength,
            is_prn: medicationForm.isPrn,
            scheduled_times: medicationForm.isPrn ? [] : scheduledTimes,
            pill_size_mg: medicationForm.pillSizeMg || null,
            is_active: true,
          },
        }),
      });

      if (!res.ok) {
        setError(await parseApiError(res));
        return;
      }

      setMedicationForm(initialMedicationForm);
      await fetchData();
    } catch {
      setError("Could not reach the server");
    } finally {
      setSavingMedication(false);
    }
  }

  async function recordDose(medication: Medication, overrides: Partial<DoseForm> = {}) {
    setError(null);
    setSavingDoseId(medication.id);

    const token = localStorage.getItem("device_token");
    if (!token) {
      router.replace("/");
      return;
    }

    const defaultForm: DoseForm = {
      doseMg: medicationDefaultDose(medication),
      doseType: medication.is_prn ? "prn" : "scheduled",
    };
    const form = { ...defaultForm, ...doseForms[medication.id], ...overrides };

    try {
      const res = await fetch(`${API}/api/v1/health_events`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          health_event: {
            metric_type: "medication_dose",
            recorded_at: new Date().toISOString(),
            client_uuid: crypto.randomUUID(),
            medication_dose_payload: {
              medication_id: medication.id,
              dose_mg: form.doseMg,
              dose_type: form.doseType,
            },
          },
        }),
      });

      if (!res.ok) {
        setError(await parseApiError(res));
        return;
      }

      await fetchData();
    } catch {
      setError("Could not reach the server");
    } finally {
      setSavingDoseId(null);
    }
  }

  return (
    <div className="min-h-screen bg-ctp-crust flex flex-col">
      <header className="flex items-center justify-between px-4 sm:px-6 py-4 border-b border-ctp-surface0">
        <div>
          <h1 className="text-xl font-semibold text-ctp-text">body ledger</h1>
          <p className="text-sm text-ctp-subtext0">Hello, {username}</p>
        </div>
        <div className="text-right">
          <p className="text-sm text-ctp-subtext1">{formatDate(now)}</p>
          <p className="text-lg font-mono text-ctp-text">{formatTime(now)}</p>
        </div>
      </header>

      <main className="flex-1 px-4 sm:px-6 py-5">
        <div className="mx-auto flex w-full max-w-6xl flex-col gap-5">
          <div>
            <h2 className="text-base font-medium text-ctp-subtext1">Medication Adherence</h2>
          </div>

          {loading && <p className="text-sm text-ctp-overlay0">Loading...</p>}
          {error && <p className="text-sm text-ctp-red">{error}</p>}

          {!loading && (
            <div className="grid gap-5 lg:grid-cols-[minmax(0,1fr)_340px]">
              <section className="flex flex-col gap-3">
                {activeMedications.length === 0 && (
                  <div className="rounded-xl border border-ctp-surface0 bg-ctp-base px-4 py-6 text-center text-sm text-ctp-overlay0">
                    Add your first medication to start logging doses.
                  </div>
                )}

                {activeMedications.map((medication) => {
                  const dose = lastDoses[medication.id];
                  const doseForm = doseForms[medication.id] ?? {
                    doseMg: medicationDefaultDose(medication),
                    doseType: medication.is_prn ? "prn" : "scheduled",
                  };

                  return (
                    <article
                      key={medication.id}
                      className="rounded-xl border border-ctp-surface0 bg-ctp-base p-4"
                    >
                      <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
                        <div>
                          <h3 className="text-lg font-medium text-ctp-text">{medication.name}</h3>
                          <p className="text-sm text-ctp-subtext0">
                            {medication.strength}
                            {medication.is_prn ? " · PRN" : ` · ${medication.scheduled_times?.join(", ") || "scheduled"}`}
                          </p>
                          <p className="mt-2 text-sm text-ctp-overlay0">
                            Last dose:{" "}
                            {dose?.payload
                              ? `${formatDose(dose.payload.dose_mg)} ${timeAgo(dose.recorded_at)}`
                              : "never"}
                          </p>
                        </div>

                        <div className="grid gap-2 sm:min-w-64">
                          <div className="grid grid-cols-[1fr_1fr] gap-2">
                            <input
                              aria-label={`${medication.name} dose in milligrams`}
                              type="number"
                              min="0"
                              step="0.001"
                              value={doseForm.doseMg}
                              onChange={(e) =>
                                setDoseForms((forms) => ({
                                  ...forms,
                                  [medication.id]: { ...doseForm, doseMg: e.target.value },
                                }))
                              }
                              className="rounded-lg bg-ctp-surface1 px-3 py-2 text-sm text-ctp-text placeholder:text-ctp-overlay0 outline-none focus:ring-2 focus:ring-ctp-blue"
                              placeholder="mg"
                            />
                            <select
                              aria-label={`${medication.name} dose type`}
                              value={doseForm.doseType}
                              onChange={(e) =>
                                setDoseForms((forms) => ({
                                  ...forms,
                                  [medication.id]: { ...doseForm, doseType: e.target.value as DoseType },
                                }))
                              }
                              className="rounded-lg bg-ctp-surface1 px-3 py-2 text-sm text-ctp-text outline-none focus:ring-2 focus:ring-ctp-blue"
                            >
                              <option value={medication.is_prn ? "prn" : "scheduled"}>
                                {medication.is_prn ? "PRN" : "Scheduled"}
                              </option>
                              {!medication.is_prn && <option value="missed">Missed</option>}
                              <option value="reconciliation">Reconciliation</option>
                            </select>
                          </div>

                          <div className="flex gap-2">
                            <button
                              type="button"
                              onClick={() => recordDose(medication)}
                              disabled={savingDoseId === medication.id}
                              className="flex-1 rounded-lg bg-[#89b4fa] px-3 py-2 text-sm font-medium text-[#1e1e2e] transition hover:bg-[#74c7ec] disabled:opacity-50"
                            >
                              {savingDoseId === medication.id ? "Saving..." : "Log dose"}
                            </button>
                            {!medication.is_prn && (
                              <button
                                type="button"
                                onClick={() => recordDose(medication, { doseType: "missed" })}
                                disabled={savingDoseId === medication.id}
                                className="rounded-lg border border-ctp-surface1 px-3 py-2 text-sm text-ctp-subtext1 transition hover:text-ctp-red disabled:opacity-50"
                              >
                                Missed
                              </button>
                            )}
                          </div>
                        </div>
                      </div>
                    </article>
                  );
                })}
              </section>

              <aside className="flex flex-col gap-5">
                <form
                  onSubmit={createMedication}
                  className="rounded-xl border border-ctp-surface0 bg-ctp-base p-4"
                >
                  <h3 className="mb-4 text-base font-medium text-ctp-text">Add medication</h3>
                  <div className="flex flex-col gap-3">
                    <input
                      aria-label="Medication name"
                      required
                      value={medicationForm.name}
                      onChange={(e) => setMedicationForm((form) => ({ ...form, name: e.target.value }))}
                      className="rounded-lg bg-ctp-surface1 px-3 py-2 text-sm text-ctp-text placeholder:text-ctp-overlay0 outline-none focus:ring-2 focus:ring-ctp-blue"
                      placeholder="Medication name"
                    />
                    <input
                      aria-label="Medication strength"
                      required
                      value={medicationForm.strength}
                      onChange={(e) => setMedicationForm((form) => ({ ...form, strength: e.target.value }))}
                      className="rounded-lg bg-ctp-surface1 px-3 py-2 text-sm text-ctp-text placeholder:text-ctp-overlay0 outline-none focus:ring-2 focus:ring-ctp-blue"
                      placeholder="Strength, e.g. 10mg"
                    />
                    <input
                      aria-label="Pill size in milligrams"
                      type="number"
                      min="0"
                      step="0.001"
                      value={medicationForm.pillSizeMg}
                      onChange={(e) => setMedicationForm((form) => ({ ...form, pillSizeMg: e.target.value }))}
                      className="rounded-lg bg-ctp-surface1 px-3 py-2 text-sm text-ctp-text placeholder:text-ctp-overlay0 outline-none focus:ring-2 focus:ring-ctp-blue"
                      placeholder="Dose per pill in mg"
                    />
                    <label className="flex items-center gap-2 text-sm text-ctp-subtext1">
                      <input
                        type="checkbox"
                        checked={medicationForm.isPrn}
                        onChange={(e) => setMedicationForm((form) => ({ ...form, isPrn: e.target.checked }))}
                        className="h-4 w-4 accent-[#89b4fa]"
                      />
                      Taken as needed
                    </label>
                    {!medicationForm.isPrn && (
                      <input
                        aria-label="Scheduled times"
                        required
                        value={medicationForm.scheduledTimes}
                        onChange={(e) => setMedicationForm((form) => ({ ...form, scheduledTimes: e.target.value }))}
                        className="rounded-lg bg-ctp-surface1 px-3 py-2 text-sm text-ctp-text placeholder:text-ctp-overlay0 outline-none focus:ring-2 focus:ring-ctp-blue"
                        placeholder="Scheduled times, e.g. 08:00, 20:00"
                      />
                    )}
                    <button
                      type="submit"
                      disabled={savingMedication}
                      className="rounded-lg bg-[#89b4fa] px-4 py-2 text-sm font-medium text-[#1e1e2e] transition hover:bg-[#74c7ec] disabled:opacity-50"
                    >
                      {savingMedication ? "Adding..." : "Add medication"}
                    </button>
                  </div>
                </form>

                <section className="rounded-xl border border-ctp-surface0 bg-ctp-base p-4">
                  <h3 className="mb-3 text-base font-medium text-ctp-text">Recent doses</h3>
                  <div className="flex flex-col gap-3">
                    {events.slice(0, 8).length === 0 && (
                      <p className="text-sm text-ctp-overlay0">No doses recorded yet.</p>
                    )}
                    {events.slice(0, 8).map((event) => {
                      const payload = event.payload;
                      if (!payload) return null;

                      return (
                        <div key={event.id} className="border-b border-ctp-surface0 pb-3 last:border-0 last:pb-0">
                          <p className="text-sm text-ctp-text">
                            {medicationNames[payload.medication_id] ?? "Medication"}
                          </p>
                          <p className="text-xs text-ctp-subtext0">
                            {formatDose(payload.dose_mg)} · {payload.dose_type} · {timeAgo(event.recorded_at)}
                          </p>
                        </div>
                      );
                    })}
                  </div>
                </section>
              </aside>
            </div>
          )}
        </div>
      </main>

      <footer className="px-4 sm:px-6 py-4 flex justify-end border-t border-ctp-surface0">
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
