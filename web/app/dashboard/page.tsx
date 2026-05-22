"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import Link from "next/link";
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
  date_started: string | null;
  rx_date: string | null;
  rx_qty: string | number | null;
  rx_per_day: string | number | null;
  dosage: string | number | null;
  dose_unit: string;
  med_form: string | null;
  med_type: string | null;
  is_active: boolean;
  created_at: string;
};

type HealthEvent = {
  id: number;
  metric_type: string;
  recorded_at: string;
  payload: Record<string, string | number | null> | null;
};

type MedicationForm = {
  name: string;
  medForm: string;
  medType: string;
  strengthPerForm: string;
  dosage: string;
  doseUnit: string;
  dateStarted: string;
  rxDate: string;
  rxQty: string;
  rxPerDay: string;
  isPrn: boolean;
  scheduledTimes: string;
};

type EntryKind = "new_medication" | "medication_dose" | "blood_pressure" | "weight" | "sleep" | "steps";

type EntryForm = {
  date: string;
  time: string;
  medicationId: string;
  doseMg: string;
  doseType: DoseType;
  doseTimingContext: "wake" | "sleep" | "other";
  readingContext: "wake" | "sleep";
  systolic: string;
  diastolic: string;
  pulse: string;
  weight: string;
  wakeTime: string;
  bedtime: string;
  sleepMinutes: string;
  steps: string;
};

function todayInputValue(): string {
  return new Date().toISOString().slice(0, 10);
}

const initialMedicationForm: MedicationForm = {
  name: "",
  medForm: "tab",
  medType: "",
  strengthPerForm: "",
  dosage: "",
  doseUnit: "mg",
  dateStarted: "",
  rxDate: "",
  rxQty: "",
  rxPerDay: "",
  isPrn: false,
  scheduledTimes: "08:00",
};

const initialEntryForm = (): EntryForm => ({
  date: todayInputValue(),
  time: new Date().toTimeString().slice(0, 5),
  medicationId: "",
  doseMg: "",
  doseType: "scheduled",
  doseTimingContext: "other",
  readingContext: "wake",
  systolic: "",
  diastolic: "",
  pulse: "",
  weight: "",
  wakeTime: "",
  bedtime: "",
  sleepMinutes: "",
  steps: "",
});

function formatTime(d: Date): string {
  return d.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", second: "2-digit" });
}

function formatDate(d: Date): string {
  return d.toLocaleDateString([], { weekday: "long", month: "long", day: "numeric" });
}

function formatDateOnly(dateStr: string | null): string {
  if (!dateStr) return "-";
  return new Date(dateStr).toLocaleDateString([], {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
}

function formatTimeOnly(dateStr: string): string {
  return new Date(dateStr).toLocaleTimeString([], {
    hour: "2-digit",
    minute: "2-digit",
  });
}

function formatDateTime(dateStr: string): string {
  return `${formatDateOnly(dateStr)} ${formatTimeOnly(dateStr)}`;
}

function formatDose(value: string | number, unit = "mg"): string {
  const dose = Number(value);
  return Number.isFinite(dose) ? `${dose} ${unit}` : `${value} ${unit}`;
}

function parseScheduledTimes(value: string): string[] {
  return value
    .split(",")
    .map((part) => part.trim())
    .filter(Boolean);
}

function minutesFromTime(value: string): number | null {
  const [hours, minutes] = value.split(":").map(Number);
  if (!Number.isFinite(hours) || !Number.isFinite(minutes)) return null;
  return hours * 60 + minutes;
}

function dateTimeFromDateAndTime(date: string, time: string): string {
  return new Date(`${date}T${time || "12:00"}:00`).toISOString();
}

function sleepDateTimes(date: string, bedtime: string, wakeTime: string): { start: string; end: string } {
  const wakeMinutes = minutesFromTime(wakeTime) ?? 0;
  const bedMinutes = minutesFromTime(bedtime) ?? 0;
  const bedDate = new Date(`${date}T00:00:00`);

  if (bedMinutes > wakeMinutes) {
    bedDate.setDate(bedDate.getDate() - 1);
  }

  return {
    start: new Date(`${bedDate.toISOString().slice(0, 10)}T${bedtime}:00`).toISOString(),
    end: dateTimeFromDateAndTime(date, wakeTime),
  };
}

function medicationDefaultDose(medication: Medication): string {
  if (medication.dosage) return String(medication.dosage);
  if (medication.pill_size_mg) return String(medication.pill_size_mg);

  const match = medication.strength.match(/(\d+(?:\.\d+)?)\s*mg/i);
  return match?.[1] ?? "";
}

function toNumber(value: string | number | null | undefined): number | null {
  if (value === null || value === undefined || value === "") return null;
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

function formatNumber(value: number | string | null | undefined, digits = 3): string {
  const number = toNumber(value);
  if (number === null) return "-";
  return Number(number.toFixed(digits)).toString();
}

function doseQuantity(doseAmount: string | number, medication: Medication): number {
  const dose = toNumber(doseAmount);
  const strengthPerForm = toNumber(medication.pill_size_mg);
  if (dose === null) return 0;
  if (!strengthPerForm) return 1;
  return dose / strengthPerForm;
}

function formatQuantity(quantity: number, medication: Medication): string {
  const rounded = Number(quantity.toFixed(3)).toString();
  const form = medication.med_form ?? "unit";
  return `${rounded} ${form}${quantity === 1 ? "" : "s"}`;
}

function eventMedicationId(event: HealthEvent): number | null {
  if (event.metric_type !== "medication_dose") return null;
  const medicationId = event.payload?.medication_id;
  return typeof medicationId === "number" ? medicationId : Number(medicationId) || null;
}

function dailyExpectedDoses(medication: Medication): number | null {
  if (medication.is_prn) return null;
  const rxPerDay = toNumber(medication.rx_per_day);
  if (rxPerDay) return rxPerDay;
  const count = medication.scheduled_times?.filter(Boolean).length ?? 0;
  return Math.max(1, count);
}

function isTakenDose(event: HealthEvent): boolean {
  return Boolean(event.metric_type === "medication_dose" && event.payload && event.payload.dose_type !== "missed");
}

function eventDoseAmount(event: HealthEvent): string | number {
  return event.payload?.dose_mg ?? 0;
}

function latestEvent(events: HealthEvent[], predicate: (event: HealthEvent) => boolean): HealthEvent | undefined {
  return events.find(predicate);
}

function formatBloodPressure(event: HealthEvent | undefined): string {
  if (!event?.payload) return "-";
  const pulse = event.payload.pulse ? ` · ${event.payload.pulse} bpm` : "";
  return `${event.payload.systolic}/${event.payload.diastolic}${pulse}`;
}

function formatWeight(event: HealthEvent | undefined): string {
  if (!event?.payload) return "-";
  if (event.payload.original_value) return `${formatNumber(event.payload.original_value, 1)} ${event.payload.original_unit ?? "lb"}`;

  const kg = toNumber(event.payload.value_kg);
  if (kg === null) return "-";
  return `${formatNumber(kg * 2.2046226218, 1)} lb`;
}

function formatSleep(event: HealthEvent | undefined): string {
  if (!event?.payload?.sleep_start || !event.payload.sleep_end) return "-";
  return `${formatTimeOnly(String(event.payload.sleep_start))} - ${formatTimeOnly(String(event.payload.sleep_end))}`;
}

function formatSteps(event: HealthEvent | undefined): string {
  if (!event?.payload?.steps) return "-";
  return formatNumber(event.payload.steps, 0);
}

function formatAdherence(taken: number, expected: number | null): string {
  if (!expected) return "PRN";
  return `${Math.round((taken / expected) * 100)}%`;
}

function normalizedMedicationName(value: string): string {
  return value.trim().toLowerCase().replace(/\s+/g, " ");
}

function isPlaceholderMedication(medication: Medication): boolean {
  return (
    toNumber(medication.pill_size_mg) === 1 &&
    toNumber(medication.dosage) === 1 &&
    medication.dose_unit === "unit" &&
    medication.med_form === "unit" &&
    !medication.date_started &&
    !medication.rx_date &&
    !medication.rx_qty &&
    !medication.rx_per_day
  );
}

function medicationStrengthLabel(medication: Medication): string {
  if (isPlaceholderMedication(medication)) return "";

  const strength = medication.pill_size_mg
    ? formatDose(medication.pill_size_mg, medication.dose_unit)
    : medication.strength;
  return `${strength} per ${medication.med_form ?? "form"}`;
}

function medicationFormFromRecord(medication: Medication): MedicationForm {
  return {
    name: medication.name,
    medForm: medication.med_form ?? "tab",
    medType: medication.med_type ?? "",
    strengthPerForm: medication.pill_size_mg ? String(medication.pill_size_mg) : "",
    dosage: medication.dosage ? String(medication.dosage) : "",
    doseUnit: medication.dose_unit || "mg",
    dateStarted: medication.date_started ?? "",
    rxDate: medication.rx_date ?? "",
    rxQty: medication.rx_qty ? String(medication.rx_qty) : "",
    rxPerDay: medication.rx_per_day ? String(medication.rx_per_day) : "",
    isPrn: medication.is_prn,
    scheduledTimes: medication.scheduled_times?.join(", ") ?? "08:00",
  };
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
  const [medicationAdminTargetId, setMedicationAdminTargetId] = useState<number | null>(null);
  const [createSeparateMedication, setCreateSeparateMedication] = useState(false);
  const [entryKind, setEntryKind] = useState<EntryKind>("medication_dose");
  const [entryForm, setEntryForm] = useState<EntryForm>(() => initialEntryForm());
  const [entryOpen, setEntryOpen] = useState(false);
  const [editOpen, setEditOpen] = useState(false);
  const [editingEvent, setEditingEvent] = useState<HealthEvent | null>(null);
  const [loading, setLoading] = useState(true);
  const [savingEntry, setSavingEntry] = useState(false);
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

  const medicationById = useMemo(() => {
    return Object.fromEntries(medications.map((medication) => [medication.id, medication]));
  }, [medications]);

  const doseEvents = useMemo(() => {
    return events.filter((event) => event.metric_type === "medication_dose");
  }, [events]);

  const medicationNameMatches = useMemo(() => {
    const normalizedName = normalizedMedicationName(medicationForm.name);
    if (!normalizedName) return [];

    return medications.filter((medication) => {
      const existingName = normalizedMedicationName(medication.name);
      return (
        existingName === normalizedName ||
        existingName.includes(normalizedName) ||
        normalizedName.includes(existingName)
      );
    });
  }, [medicationForm.name, medications]);

  const exactMedicationNameMatch = useMemo(() => {
    const normalizedName = normalizedMedicationName(medicationForm.name);
    if (!normalizedName) return undefined;
    return medications.find((medication) => normalizedMedicationName(medication.name) === normalizedName);
  }, [medicationForm.name, medications]);

  const medicationAdminTarget = useMemo(() => {
    if (createSeparateMedication) return undefined;
    if (medicationAdminTargetId) return medicationById[medicationAdminTargetId];
    return exactMedicationNameMatch;
  }, [createSeparateMedication, exactMedicationNameMatch, medicationAdminTargetId, medicationById]);

  const healthMetrics = useMemo(() => {
    const amBp = latestEvent(
      events,
      (event) => event.metric_type === "blood_pressure" && event.payload?.reading_context === "wake",
    );
    const pmBp = latestEvent(
      events,
      (event) => event.metric_type === "blood_pressure" && event.payload?.reading_context === "sleep",
    );
    const weight = latestEvent(events, (event) => event.metric_type === "weight");
    const sleep = latestEvent(events, (event) => event.metric_type === "sleep");
    const steps = latestEvent(
      events,
      (event) => event.metric_type === "activity" && event.payload?.activity_type === "steps",
    );

    return [
      {
        label: "AM BP / HR",
        value: formatBloodPressure(amBp),
        meta: amBp ? formatTimeOnly(amBp.recorded_at) : "No wake reading",
      },
      {
        label: "PM BP / HR",
        value: formatBloodPressure(pmBp),
        meta: pmBp ? formatTimeOnly(pmBp.recorded_at) : "No sleep reading",
      },
      {
        label: "Weight",
        value: formatWeight(weight),
        meta: weight ? formatDateOnly(weight.recorded_at) : "No weight logged",
      },
      {
        label: "Sleep",
        value: formatSleep(sleep),
        meta: sleep ? formatDateOnly(sleep.recorded_at) : "No sleep logged",
      },
      {
        label: "Steps",
        value: formatSteps(steps),
        meta: steps ? formatDateOnly(steps.recorded_at) : "No steps logged",
      },
    ];
  }, [events]);

  const editableEvents = useMemo(() => {
    return events.filter((event) => {
      if (event.metric_type === "activity") return event.payload?.activity_type === "steps";
      return ["medication_dose", "blood_pressure", "weight", "sleep"].includes(event.metric_type);
    });
  }, [events]);

  function recordLabel(event: HealthEvent): string {
    const payload = event.payload ?? {};

    if (event.metric_type === "medication_dose") {
      const medicationId = eventMedicationId(event);
      return medicationId ? `Medication dose · ${medicationNames[medicationId] ?? "Medication"}` : "Medication dose";
    }

    if (event.metric_type === "blood_pressure") {
      const context = payload.reading_context === "sleep" ? "PM" : "AM";
      return `${context} BP / HR · ${formatBloodPressure(event)}`;
    }

    if (event.metric_type === "weight") return `Weight · ${formatWeight(event)}`;
    if (event.metric_type === "sleep") return `Sleep · ${formatSleep(event)}`;
    if (event.metric_type === "activity" && payload.activity_type === "steps") return `Steps · ${formatSteps(event)}`;

    return "Record";
  }

  const basicRows = useMemo(() => {
    return activeMedications.map((medication) => {
      const medEvents = doseEvents.filter((event) => eventMedicationId(event) === medication.id);
      const takenEvents = medEvents.filter(isTakenDose);
      const lastEvent = medEvents[0];

      return {
        medication,
        takenQty: takenEvents.reduce((sum, event) => {
          return sum + (event.payload ? doseQuantity(eventDoseAmount(event), medication) : 0);
        }, 0),
        lastQty: lastEvent?.payload
          ? formatQuantity(doseQuantity(eventDoseAmount(lastEvent), medication), medication)
          : "-",
        lastAt: lastEvent ? formatDateTime(lastEvent.recorded_at) : "-",
      };
    });
  }, [activeMedications, doseEvents]);

  const adherenceRows = useMemo(() => {
    const nowMs = Date.now();

    return activeMedications.map((medication) => {
      const perDay = dailyExpectedDoses(medication);

      const takenInWindow = (days: number) => {
        const cutoff = nowMs - days * 24 * 60 * 60 * 1000;
        return events.reduce((sum, event) => {
          if (
            eventMedicationId(event) === medication.id &&
            isTakenDose(event) &&
            new Date(event.recorded_at).getTime() >= cutoff
          ) {
            return sum + (event.payload ? doseQuantity(eventDoseAmount(event), medication) : 0);
          }
          return sum;
        }, 0);
      };

      const taken7 = takenInWindow(7);
      const taken30 = takenInWindow(30);

      return {
        medication,
        adherence7: formatAdherence(taken7, perDay ? perDay * 7 : null),
        adherence30: formatAdherence(taken30, perDay ? perDay * 30 : null),
        lastTaken: lastDoses[medication.id]?.recorded_at
          ? formatDateTime(lastDoses[medication.id].recorded_at)
          : "-",
      };
    });
  }, [activeMedications, events, lastDoses]);

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
        fetch(`${API}/api/v1/health_events`, { headers }),
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
      const healthEvents: HealthEvent[] = await eventsRes.json();

      healthEvents.sort((a, b) => new Date(b.recorded_at).getTime() - new Date(a.recorded_at).getTime());
      setMedications(meds);
      setEvents(healthEvents);
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

  function openEntryModal(kind: EntryKind = activeMedications.length > 0 ? "medication_dose" : "new_medication") {
    const firstMedication = activeMedications[0];
    setEditingEvent(null);
    setEntryKind(kind);
    setMedicationAdminTargetId(null);
    setCreateSeparateMedication(false);
    setEntryForm({
      ...initialEntryForm(),
      medicationId: firstMedication ? String(firstMedication.id) : "",
      doseMg: firstMedication ? medicationDefaultDose(firstMedication) : "",
      doseType: firstMedication?.is_prn ? "prn" : "scheduled",
    });
    setError(null);
    setEntryOpen(true);
  }

  function openEditModal(event: HealthEvent) {
    const recordedAt = new Date(event.recorded_at);
    const payload = event.payload ?? {};
    const nextForm = {
      ...initialEntryForm(),
      date: recordedAt.toISOString().slice(0, 10),
      time: recordedAt.toTimeString().slice(0, 5),
    };

    if (event.metric_type === "medication_dose") {
      setEntryKind("medication_dose");
      setEntryForm({
        ...nextForm,
        medicationId: String(payload.medication_id ?? ""),
        doseMg: String(payload.dose_mg ?? ""),
        doseType: (payload.dose_type as DoseType) ?? "scheduled",
        doseTimingContext: payload.timing_context === "wake" || payload.timing_context === "sleep" ? payload.timing_context : "other",
      });
    }

    if (event.metric_type === "blood_pressure") {
      setEntryKind("blood_pressure");
      setEntryForm({
        ...nextForm,
        readingContext: payload.reading_context === "sleep" ? "sleep" : "wake",
        systolic: String(payload.systolic ?? ""),
        diastolic: String(payload.diastolic ?? ""),
        pulse: String(payload.pulse ?? ""),
      });
    }

    if (event.metric_type === "weight") {
      const kg = toNumber(payload.value_kg);
      setEntryKind("weight");
      setEntryForm({
        ...nextForm,
        weight: String(payload.original_value ?? (kg === null ? "" : formatNumber(kg * 2.2046226218, 1))),
      });
    }

    if (event.metric_type === "sleep") {
      const sleepStart = payload.sleep_start ? new Date(String(payload.sleep_start)) : recordedAt;
      const sleepEnd = payload.sleep_end ? new Date(String(payload.sleep_end)) : recordedAt;
      setEntryKind("sleep");
      setEntryForm({
        ...nextForm,
        date: sleepEnd.toISOString().slice(0, 10),
        bedtime: sleepStart.toTimeString().slice(0, 5),
        wakeTime: sleepEnd.toTimeString().slice(0, 5),
        sleepMinutes: String(payload.sleep_minutes ?? ""),
      });
    }

    if (event.metric_type === "activity" && payload.activity_type === "steps") {
      setEntryKind("steps");
      setEntryForm({
        ...nextForm,
        steps: String(payload.steps ?? ""),
      });
    }

    setEditingEvent(event);
    setEditOpen(false);
    setError(null);
    setEntryOpen(true);
  }

  function changeEntryKind(kind: EntryKind) {
    const firstMedication = activeMedications[0];
    setEntryKind(kind);
    setEntryForm((form) => ({
      ...form,
      medicationId: form.medicationId || (firstMedication ? String(firstMedication.id) : ""),
      doseMg: form.doseMg || (firstMedication ? medicationDefaultDose(firstMedication) : ""),
      doseType: firstMedication?.is_prn ? "prn" : form.doseType,
    }));
  }

  function selectedEntryMedication(): Medication | undefined {
    return medicationById[Number(entryForm.medicationId)];
  }

  async function createHealthEvent(
    token: string,
    metricType: string,
    recordedAt: string,
    payloadKey: string,
    payload: Record<string, string | number | null>,
    eventId?: number,
  ) {
    const res = await fetch(`${API}/api/v1/health_events${eventId ? `/${eventId}/amend` : ""}`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        health_event: {
          metric_type: metricType,
          recorded_at: recordedAt,
          client_uuid: crypto.randomUUID(),
          [payloadKey]: payload,
        },
      }),
    });

    if (!res.ok) {
      throw new Error(await parseApiError(res));
    }
  }

  async function saveEntry(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setSavingEntry(true);

    const token = localStorage.getItem("device_token");
    if (!token) {
      router.replace("/");
      return;
    }

    const recordedAt = dateTimeFromDateAndTime(entryForm.date, entryForm.time);
    const amendEventId = editingEvent?.id;

    try {
      if (entryKind === "new_medication") {
        const saved = await createMedicationRecord(token);
        if (saved) setEntryOpen(false);
        return;
      }

      if (entryKind === "medication_dose") {
        await createHealthEvent(token, "medication_dose", recordedAt, "medication_dose_payload", {
          medication_id: Number(entryForm.medicationId),
          dose_mg: entryForm.doseMg,
          dose_type: entryForm.doseType,
          timing_context: entryForm.doseTimingContext,
        }, amendEventId);
      }

      if (entryKind === "blood_pressure") {
        await createHealthEvent(token, "blood_pressure", recordedAt, "blood_pressure_payload", {
          systolic: entryForm.systolic,
          diastolic: entryForm.diastolic,
          pulse: entryForm.pulse || null,
          reading_context: entryForm.readingContext,
        }, amendEventId);
      }

      if (entryKind === "weight") {
        const weightKg = Number(entryForm.weight) * 0.45359237;
        await createHealthEvent(token, "weight", recordedAt, "weight_payload", {
          value_kg: weightKg,
          original_unit: "lb",
          original_value: entryForm.weight,
        }, amendEventId);
      }

      if (entryKind === "sleep") {
        const sleep = sleepDateTimes(entryForm.date, entryForm.bedtime, entryForm.wakeTime);
        await createHealthEvent(token, "sleep", sleep.end, "sleep_payload", {
          sleep_start: sleep.start,
          sleep_end: sleep.end,
          sleep_minutes: entryForm.sleepMinutes || null,
        }, amendEventId);
      }

      if (entryKind === "steps") {
        await createHealthEvent(token, "activity", recordedAt, "activity_payload", {
          activity_type: "steps",
          duration_minutes: 1,
          steps: entryForm.steps,
        }, amendEventId);
      }

      setEditingEvent(null);
      setEntryOpen(false);
      await fetchData();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Could not save entry");
    } finally {
      setSavingEntry(false);
    }
  }

  async function createMedicationRecord(token: string): Promise<boolean> {
    const scheduledTimes = parseScheduledTimes(medicationForm.scheduledTimes);
    const strength = `${medicationForm.strengthPerForm}${medicationForm.doseUnit} ${medicationForm.medForm}`;
    const targetMedication = medicationAdminTarget;

    try {
      const res = await fetch(`${API}/api/v1/medications${targetMedication ? `/${targetMedication.id}` : ""}`, {
        method: targetMedication ? "PATCH" : "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          medication: {
            name: medicationForm.name,
            strength,
            med_form: medicationForm.medForm,
            med_type: medicationForm.medType || null,
            pill_size_mg: medicationForm.strengthPerForm,
            dosage: medicationForm.dosage,
            dose_unit: medicationForm.doseUnit,
            date_started: medicationForm.dateStarted || null,
            rx_date: medicationForm.rxDate || null,
            rx_qty: medicationForm.rxQty || null,
            rx_per_day: medicationForm.rxPerDay || null,
            is_prn: medicationForm.isPrn,
            scheduled_times: medicationForm.isPrn ? [] : scheduledTimes,
            is_active: true,
          },
        }),
      });

      if (!res.ok) {
        setError(await parseApiError(res));
        return false;
      }

      setMedicationForm(initialMedicationForm);
      setMedicationAdminTargetId(null);
      setCreateSeparateMedication(false);
      await fetchData();
      return true;
    } catch {
      setError("Could not reach the server");
      return false;
    }
  }

  async function mergeMedicationRecord(sourceMedicationId: number, targetMedicationId: number) {
    const token = localStorage.getItem("device_token");
    if (!token) {
      router.replace("/");
      return;
    }

    setError(null);
    setSavingEntry(true);

    try {
      const res = await fetch(`${API}/api/v1/medications/${targetMedicationId}/merge`, {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ source_medication_id: sourceMedicationId }),
      });

      if (!res.ok) {
        setError(await parseApiError(res));
        return;
      }

      setMedicationAdminTargetId(targetMedicationId);
      await fetchData();
    } catch {
      setError("Could not reach the server");
    } finally {
      setSavingEntry(false);
    }
  }

  return (
    <div className="min-h-screen bg-ctp-crust flex flex-col">
      <header className="flex flex-col gap-3 px-4 py-4 border-b border-ctp-surface0 sm:flex-row sm:items-center sm:justify-between sm:px-6">
        <div>
          <h1 className="text-xl font-semibold text-ctp-text">body ledger</h1>
          <p className="text-sm text-ctp-subtext0">Hello, {username}</p>
        </div>
        <div className="text-left sm:text-right">
          <p className="text-sm text-ctp-subtext1">{formatDate(now)}</p>
          <p className="text-lg font-mono text-ctp-text">{formatTime(now)}</p>
        </div>
      </header>

      <main className="flex-1 px-3 py-4 sm:px-6 sm:py-5">
        <div className="mx-auto flex w-full max-w-7xl flex-col gap-5">
          <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <h2 className="text-base font-medium text-ctp-subtext1">Health Dashboard</h2>
            <div className="flex flex-wrap gap-2">
              <Link
                href="/reports"
                className="rounded-lg border border-ctp-surface1 px-4 py-2 text-sm font-medium text-ctp-text transition hover:border-ctp-blue"
              >
                Reports
              </Link>
              <button
                type="button"
                onClick={() => openEntryModal()}
                className="rounded-lg bg-[#89b4fa] px-4 py-2 text-sm font-medium text-[#1e1e2e] transition hover:bg-[#74c7ec]"
              >
                Add record
              </button>
              <button
                type="button"
                onClick={() => setEditOpen(true)}
                className="rounded-lg border border-ctp-surface1 px-4 py-2 text-sm font-medium text-ctp-text transition hover:border-ctp-blue"
              >
                Edit records
              </button>
            </div>
          </div>

          {loading && <p className="text-sm text-ctp-overlay0">Loading...</p>}
          {error && <p className="text-sm text-ctp-red">{error}</p>}

          {!loading && (
            <div className="grid gap-5">
              <section className="flex min-w-0 flex-col gap-5">
                <section className="rounded-xl border border-ctp-surface0 bg-ctp-base">
                  <div className="border-b border-ctp-surface0 px-4 py-3">
                    <h3 className="text-base font-medium text-ctp-text">Health Metrics</h3>
                  </div>
                  <div className="grid gap-px bg-ctp-surface0 sm:grid-cols-2 lg:grid-cols-5">
                    {healthMetrics.map((metric) => (
                      <div key={metric.label} className="bg-ctp-base p-4">
                        <p className="text-xs font-medium uppercase tracking-wide text-ctp-overlay0">{metric.label}</p>
                        <p className="mt-2 text-lg font-semibold text-ctp-text">{metric.value}</p>
                        <p className="mt-1 text-xs text-ctp-subtext0">{metric.meta}</p>
                      </div>
                    ))}
                  </div>
                </section>

                <section className="rounded-xl border border-ctp-surface0 bg-ctp-base">
                  <div className="border-b border-ctp-surface0 px-4 py-3">
                    <h3 className="text-base font-medium text-ctp-text">Basic Med Info</h3>
                  </div>
                  <div className="divide-y divide-ctp-surface0 md:hidden">
                    {basicRows.length === 0 && (
                      <p className="px-4 py-4 text-center text-sm text-ctp-overlay0">
                        Add your first medication to start logging doses.
                      </p>
                    )}
                    {basicRows.map((row) => (
                      <div key={row.medication.id} className="p-4">
                        <div className="mb-3">
                          <p className="text-base font-medium text-ctp-text">{row.medication.name}</p>
                          {medicationStrengthLabel(row.medication) && (
                            <p className="text-xs text-ctp-overlay0">{medicationStrengthLabel(row.medication)}</p>
                          )}
                        </div>
                        <dl className="grid grid-cols-2 gap-x-3 gap-y-2 text-sm">
                          <dt className="text-ctp-overlay0">Started</dt>
                          <dd className="text-ctp-subtext0">{formatDateOnly(row.medication.date_started)}</dd>
                          <dt className="text-ctp-overlay0">Rx Date</dt>
                          <dd className="text-ctp-subtext0">{formatDateOnly(row.medication.rx_date)}</dd>
                          <dt className="text-ctp-overlay0">Rx Qty</dt>
                          <dd className="text-ctp-subtext0">{formatNumber(row.medication.rx_qty)}</dd>
                          <dt className="text-ctp-overlay0">Rx/Day</dt>
                          <dd className="text-ctp-subtext0">{formatNumber(row.medication.rx_per_day)}</dd>
                          <dt className="text-ctp-overlay0">Taken Qty</dt>
                          <dd className="text-ctp-subtext0">{formatQuantity(row.takenQty, row.medication)}</dd>
                          <dt className="text-ctp-overlay0">Last Qty</dt>
                          <dd className="text-ctp-subtext0">{row.lastQty}</dd>
                          <dt className="text-ctp-overlay0">Dosage</dt>
                          <dd className="text-ctp-subtext0">
                            {row.medication.dosage ? formatDose(row.medication.dosage, row.medication.dose_unit) : "-"}
                          </dd>
                          <dt className="text-ctp-overlay0">Form</dt>
                          <dd className="text-ctp-subtext0">{row.medication.med_form ?? "-"}</dd>
                        </dl>
                      </div>
                    ))}
                  </div>
                  {basicRows.length === 0 ? (
                    <p className="hidden px-4 py-6 text-center text-sm text-ctp-overlay0 md:block">
                      Add your first medication to start logging doses.
                    </p>
                  ) : (
                    <div className="hidden overflow-x-auto md:block">
                    <table className="w-full min-w-[980px] text-sm">
                      <thead className="bg-ctp-surface0 text-ctp-subtext1">
                        <tr>
                          <th className="px-4 py-2.5 text-left font-medium">Med</th>
                          <th className="px-4 py-2.5 text-left font-medium">Started</th>
                          <th className="px-4 py-2.5 text-left font-medium">Rx Date</th>
                          <th className="px-4 py-2.5 text-left font-medium">Rx Qty</th>
                          <th className="px-4 py-2.5 text-left font-medium">Rx/Day</th>
                          <th className="px-4 py-2.5 text-left font-medium">Taken Qty</th>
                          <th className="px-4 py-2.5 text-left font-medium">Last Qty</th>
                          <th className="px-4 py-2.5 text-left font-medium">Dosage</th>
                          <th className="px-4 py-2.5 text-left font-medium">Unit</th>
                          <th className="px-4 py-2.5 text-left font-medium">Form</th>
                        </tr>
                      </thead>
                      <tbody>
                        {basicRows.map((row, index) => (
                          <tr key={row.medication.id} className={index % 2 === 0 ? "bg-ctp-base" : "bg-ctp-mantle"}>
                            <td className="px-4 py-3 text-ctp-text">
                              {row.medication.name}
                              {medicationStrengthLabel(row.medication) && (
                                <span className="ml-2 text-ctp-overlay0">{medicationStrengthLabel(row.medication)}</span>
                              )}
                            </td>
                            <td className="px-4 py-3 text-ctp-subtext0">{formatDateOnly(row.medication.date_started)}</td>
                            <td className="px-4 py-3 text-ctp-subtext0">{formatDateOnly(row.medication.rx_date)}</td>
                            <td className="px-4 py-3 text-ctp-subtext0">{formatNumber(row.medication.rx_qty)}</td>
                            <td className="px-4 py-3 text-ctp-subtext0">{formatNumber(row.medication.rx_per_day)}</td>
                            <td className="px-4 py-3 text-ctp-subtext0">{formatQuantity(row.takenQty, row.medication)}</td>
                            <td className="px-4 py-3 text-ctp-subtext0">{row.lastQty}</td>
                            <td className="px-4 py-3 text-ctp-subtext0">
                              {row.medication.dosage ? formatDose(row.medication.dosage, row.medication.dose_unit) : "-"}
                            </td>
                            <td className="px-4 py-3 text-ctp-subtext0">{row.medication.dose_unit}</td>
                            <td className="px-4 py-3 text-ctp-subtext0">{row.medication.med_form ?? "-"}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                  )}
                </section>

                <section className="rounded-xl border border-ctp-surface0 bg-ctp-base">
                  <div className="border-b border-ctp-surface0 px-4 py-3">
                    <h3 className="text-base font-medium text-ctp-text">Adherence Tracking</h3>
                  </div>
                  <div className="divide-y divide-ctp-surface0 md:hidden">
                    {adherenceRows.length === 0 && (
                      <p className="px-4 py-4 text-center text-sm text-ctp-overlay0">No adherence data yet.</p>
                    )}
                    {adherenceRows.map((row) => (
                      <div key={row.medication.id} className="p-4">
                        <p className="mb-3 text-base font-medium text-ctp-text">{row.medication.name}</p>
                        <dl className="grid grid-cols-2 gap-x-3 gap-y-2 text-sm">
                          <dt className="text-ctp-overlay0">Adherence 7d</dt>
                          <dd className="text-ctp-subtext0">{row.adherence7}</dd>
                          <dt className="text-ctp-overlay0">Adherence 30d</dt>
                          <dd className="text-ctp-subtext0">{row.adherence30}</dd>
                          <dt className="text-ctp-overlay0">Last Taken</dt>
                          <dd className="text-ctp-subtext0">{row.lastTaken}</dd>
                        </dl>
                      </div>
                    ))}
                  </div>
                  {adherenceRows.length === 0 ? (
                    <p className="hidden px-4 py-6 text-center text-sm text-ctp-overlay0 md:block">
                      No adherence data yet.
                    </p>
                  ) : (
                    <div className="hidden overflow-x-auto md:block">
                    <table className="w-full min-w-[620px] text-sm">
                      <thead className="bg-ctp-surface0 text-ctp-subtext1">
                        <tr>
                          <th className="px-4 py-2.5 text-left font-medium">Medication</th>
                          <th className="px-4 py-2.5 text-left font-medium">Adherence 7d</th>
                          <th className="px-4 py-2.5 text-left font-medium">Adherence 30d</th>
                          <th className="px-4 py-2.5 text-left font-medium">Last Taken</th>
                        </tr>
                      </thead>
                      <tbody>
                        {adherenceRows.map((row, index) => (
                          <tr key={row.medication.id} className={index % 2 === 0 ? "bg-ctp-base" : "bg-ctp-mantle"}>
                            <td className="px-4 py-3 text-ctp-text">{row.medication.name}</td>
                            <td className="px-4 py-3 text-ctp-subtext0">{row.adherence7}</td>
                            <td className="px-4 py-3 text-ctp-subtext0">{row.adherence30}</td>
                            <td className="px-4 py-3 text-ctp-subtext0">{row.lastTaken}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                  )}
                </section>

                <section className="rounded-xl border border-ctp-surface0 bg-ctp-base">
                  <div className="border-b border-ctp-surface0 px-4 py-3">
                    <h3 className="text-base font-medium text-ctp-text">Recent Dose Logs</h3>
                  </div>
                  <div className="divide-y divide-ctp-surface0 md:hidden">
                    {doseEvents.slice(0, 20).length === 0 && (
                      <p className="px-4 py-4 text-center text-sm text-ctp-overlay0">No doses recorded yet.</p>
                    )}
                    {doseEvents.slice(0, 20).map((event) => {
                      const payload = event.payload;
                      if (!payload) return null;
                      const medicationId = eventMedicationId(event);
                      if (!medicationId) return null;
                      const medication = medicationById[medicationId];

                      return (
                        <div key={event.id} className="p-4">
                          <p className="text-sm font-medium text-ctp-text">
                            {medicationNames[medicationId] ?? "Medication"}
                          </p>
                          <p className="mt-1 text-xs text-ctp-overlay0">
                            {formatDateOnly(event.recorded_at)} {formatTimeOnly(event.recorded_at)}
                          </p>
                          <p className="mt-2 text-sm text-ctp-subtext0">
                            {medication ? formatQuantity(doseQuantity(eventDoseAmount(event), medication), medication) : "-"} · {payload.dose_type}
                          </p>
                        </div>
                      );
                    })}
                  </div>
                  {doseEvents.slice(0, 20).length === 0 ? (
                    <p className="hidden px-4 py-6 text-center text-sm text-ctp-overlay0 md:block">
                      No doses recorded yet.
                    </p>
                  ) : (
                    <div className="hidden overflow-x-auto md:block">
                    <table className="w-full min-w-[700px] text-sm">
                      <thead className="bg-ctp-surface0 text-ctp-subtext1">
                        <tr>
                          <th className="px-4 py-2.5 text-left font-medium">Date</th>
                          <th className="px-4 py-2.5 text-left font-medium">Time</th>
                          <th className="px-4 py-2.5 text-left font-medium">Medication</th>
                          <th className="px-4 py-2.5 text-left font-medium">Qty</th>
                          <th className="px-4 py-2.5 text-left font-medium">Type</th>
                        </tr>
                      </thead>
                      <tbody>
                        {doseEvents.slice(0, 20).map((event, index) => {
                          const payload = event.payload;
                          if (!payload) return null;
                          const medicationId = eventMedicationId(event);
                          if (!medicationId) return null;
                          const medication = medicationById[medicationId];

                          return (
                            <tr key={event.id} className={index % 2 === 0 ? "bg-ctp-base" : "bg-ctp-mantle"}>
                              <td className="px-4 py-3 text-ctp-subtext0">{formatDateOnly(event.recorded_at)}</td>
                              <td className="px-4 py-3 text-ctp-subtext0">{formatTimeOnly(event.recorded_at)}</td>
                              <td className="px-4 py-3 text-ctp-text">{medicationNames[medicationId] ?? "Medication"}</td>
                              <td className="px-4 py-3 text-ctp-subtext0">
                                {medication ? formatQuantity(doseQuantity(eventDoseAmount(event), medication), medication) : "-"}
                              </td>
                              <td className="px-4 py-3 text-ctp-subtext0">{payload.dose_type}</td>
                            </tr>
                          );
                        })}
                      </tbody>
                    </table>
                  </div>
                  )}
                </section>
              </section>

            </div>
          )}
        </div>
      </main>

      {entryOpen && (
        <div className="fixed inset-0 z-50 flex items-end bg-black/70 p-0 sm:items-center sm:justify-center sm:p-6">
          <form
            onSubmit={saveEntry}
            className="max-h-[92vh] w-full overflow-y-auto rounded-t-xl border border-ctp-surface0 bg-ctp-base p-4 shadow-xl sm:max-w-lg sm:rounded-xl sm:p-5"
          >
            <div className="mb-4 flex items-center justify-between gap-4">
              <h3 className="text-lg font-medium text-ctp-text">{editingEvent ? "Edit record" : "Add record"}</h3>
              <button
                type="button"
                onClick={() => {
                  setEntryOpen(false);
                  setEditingEvent(null);
                }}
                className="rounded-lg border border-ctp-surface1 px-3 py-1.5 text-sm text-ctp-subtext1 hover:text-ctp-text"
              >
                Close
              </button>
            </div>

            <div className="flex flex-col gap-3">
              <select
                aria-label="Data type"
                value={entryKind}
                disabled={Boolean(editingEvent)}
                onChange={(e) => changeEntryKind(e.target.value as EntryKind)}
                className="rounded-lg bg-ctp-surface1 px-3 py-2 text-sm text-ctp-text outline-none focus:ring-2 focus:ring-ctp-blue disabled:opacity-70"
              >
                {!editingEvent && <option value="new_medication">New medication</option>}
                <option value="medication_dose">Medication dose</option>
                <option value="blood_pressure">Blood pressure / heart rate</option>
                <option value="weight">Weight</option>
                <option value="sleep">Sleep</option>
                <option value="steps">Steps</option>
              </select>

              {entryKind === "new_medication" && (
                <>
                  <input
                    aria-label="Medication name"
                    required
                    value={medicationForm.name}
                    onChange={(e) => {
                      setMedicationAdminTargetId(null);
                      setCreateSeparateMedication(false);
                      setMedicationForm((form) => ({ ...form, name: e.target.value }));
                    }}
                    className="rounded-lg bg-ctp-surface1 px-3 py-2 text-sm text-ctp-text placeholder:text-ctp-overlay0 outline-none focus:ring-2 focus:ring-ctp-blue"
                    placeholder="Medication name, e.g. lisinopril"
                  />
                  {medicationNameMatches.length > 0 && (
                    <div className="rounded-lg border border-ctp-surface1 bg-ctp-mantle p-3">
                      <p className="text-sm font-medium text-ctp-text">
                        {medicationAdminTarget ? "Updating existing medication" : "Existing medication match"}
                      </p>
                      <div className="mt-2 flex flex-col gap-2">
                        {medicationNameMatches.slice(0, 4).map((medication) => (
                          <div
                            key={medication.id}
                            className={`rounded-lg border px-3 py-2 text-left text-sm transition ${
                              medicationAdminTarget?.id === medication.id
                                ? "border-ctp-blue bg-ctp-surface0 text-ctp-text"
                                : "border-ctp-surface0 text-ctp-subtext1 hover:border-ctp-blue hover:text-ctp-text"
                            }`}
                          >
                            <div className="flex items-start justify-between gap-3">
                              <button
                                type="button"
                                onClick={() => {
                                  setMedicationAdminTargetId(medication.id);
                                  setCreateSeparateMedication(false);
                                  setMedicationForm({
                                    ...medicationFormFromRecord(medication),
                                    name: medicationForm.name.trim() || medication.name,
                                  });
                                }}
                                className="min-w-0 flex-1 text-left"
                              >
                                <span className="block font-medium">{medication.name}</span>
                                <span className="mt-0.5 block text-xs text-ctp-overlay0">
                                  {isPlaceholderMedication(medication)
                                    ? "Imported placeholder"
                                    : medicationStrengthLabel(medication) || "Medication details"}
                                </span>
                              </button>
                              {medicationAdminTarget && medicationAdminTarget.id !== medication.id && (
                                <button
                                  type="button"
                                  disabled={savingEntry}
                                  onClick={() => mergeMedicationRecord(medication.id, medicationAdminTarget.id)}
                                  className="shrink-0 rounded-md border border-ctp-surface1 px-2 py-1 text-xs text-ctp-blue hover:border-ctp-blue disabled:opacity-50"
                                >
                                  Merge
                                </button>
                              )}
                            </div>
                          </div>
                        ))}
                      </div>
                      <label className="mt-3 flex items-center gap-2 text-sm text-ctp-subtext1">
                        <input
                          type="checkbox"
                          checked={createSeparateMedication}
                          onChange={(e) => {
                            setCreateSeparateMedication(e.target.checked);
                            if (e.target.checked) setMedicationAdminTargetId(null);
                          }}
                          className="h-4 w-4 accent-[#89b4fa]"
                        />
                        Create a separate medication instead
                      </label>
                    </div>
                  )}
                  <div className="grid grid-cols-[1fr_84px] gap-2">
                    <input
                      aria-label="Strength per form"
                      required
                      type="number"
                      min="0"
                      step="0.001"
                      value={medicationForm.strengthPerForm}
                      onChange={(e) => setMedicationForm((form) => ({ ...form, strengthPerForm: e.target.value }))}
                      className="rounded-lg bg-ctp-surface1 px-3 py-2 text-sm text-ctp-text placeholder:text-ctp-overlay0 outline-none focus:ring-2 focus:ring-ctp-blue"
                      placeholder="Strength per form, e.g. 10"
                    />
                    <input
                      aria-label="Dose unit"
                      required
                      value={medicationForm.doseUnit}
                      onChange={(e) => setMedicationForm((form) => ({ ...form, doseUnit: e.target.value }))}
                      className="rounded-lg bg-ctp-surface1 px-3 py-2 text-sm text-ctp-text placeholder:text-ctp-overlay0 outline-none focus:ring-2 focus:ring-ctp-blue"
                      placeholder="mg"
                    />
                  </div>
                  <input
                    aria-label="Medication form"
                    required
                    value={medicationForm.medForm}
                    onChange={(e) => setMedicationForm((form) => ({ ...form, medForm: e.target.value }))}
                    className="rounded-lg bg-ctp-surface1 px-3 py-2 text-sm text-ctp-text placeholder:text-ctp-overlay0 outline-none focus:ring-2 focus:ring-ctp-blue"
                    placeholder="Form, e.g. tab"
                  />
                  <input
                    aria-label="Medication type"
                    value={medicationForm.medType}
                    onChange={(e) => setMedicationForm((form) => ({ ...form, medType: e.target.value }))}
                    className="rounded-lg bg-ctp-surface1 px-3 py-2 text-sm text-ctp-text placeholder:text-ctp-overlay0 outline-none focus:ring-2 focus:ring-ctp-blue"
                    placeholder="Medication type, e.g. Cannabis"
                  />
                  <input
                    aria-label="Dosage"
                    required
                    type="number"
                    min="0"
                    step="0.001"
                    value={medicationForm.dosage}
                    onChange={(e) => setMedicationForm((form) => ({ ...form, dosage: e.target.value }))}
                    className="rounded-lg bg-ctp-surface1 px-3 py-2 text-sm text-ctp-text placeholder:text-ctp-overlay0 outline-none focus:ring-2 focus:ring-ctp-blue"
                    placeholder="Dosage, e.g. 15"
                  />
                  <div className="grid grid-cols-2 gap-2">
                    <input
                      aria-label="Date started"
                      type="date"
                      value={medicationForm.dateStarted}
                      onChange={(e) => setMedicationForm((form) => ({ ...form, dateStarted: e.target.value }))}
                      className="rounded-lg bg-ctp-surface1 px-3 py-2 text-sm text-ctp-text outline-none focus:ring-2 focus:ring-ctp-blue"
                    />
                    <input
                      aria-label="Prescription date"
                      type="date"
                      value={medicationForm.rxDate}
                      onChange={(e) => setMedicationForm((form) => ({ ...form, rxDate: e.target.value }))}
                      className="rounded-lg bg-ctp-surface1 px-3 py-2 text-sm text-ctp-text outline-none focus:ring-2 focus:ring-ctp-blue"
                    />
                  </div>
                  <div className="grid grid-cols-2 gap-2">
                    <input
                      aria-label="Prescription quantity"
                      type="number"
                      min="0"
                      step="0.001"
                      value={medicationForm.rxQty}
                      onChange={(e) => setMedicationForm((form) => ({ ...form, rxQty: e.target.value }))}
                      className="rounded-lg bg-ctp-surface1 px-3 py-2 text-sm text-ctp-text placeholder:text-ctp-overlay0 outline-none focus:ring-2 focus:ring-ctp-blue"
                      placeholder="Rx qty"
                    />
                    <input
                      aria-label="Prescription quantity per day"
                      type="number"
                      min="0"
                      step="0.001"
                      value={medicationForm.rxPerDay}
                      onChange={(e) => setMedicationForm((form) => ({ ...form, rxPerDay: e.target.value }))}
                      className="rounded-lg bg-ctp-surface1 px-3 py-2 text-sm text-ctp-text placeholder:text-ctp-overlay0 outline-none focus:ring-2 focus:ring-ctp-blue"
                      placeholder="Rx per day"
                    />
                  </div>
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
                </>
              )}

              {entryKind !== "new_medication" && (
                <div className="grid grid-cols-2 gap-2">
                  <input
                    aria-label="Entry date"
                    type="date"
                    required
                    value={entryForm.date}
                    onChange={(e) => setEntryForm((form) => ({ ...form, date: e.target.value }))}
                    className="rounded-lg bg-ctp-surface1 px-3 py-2 text-sm text-ctp-text outline-none focus:ring-2 focus:ring-ctp-blue"
                  />
                  {entryKind !== "sleep" && (
                    <input
                      aria-label="Entry time"
                      type="time"
                      required
                      value={entryForm.time}
                      onChange={(e) => setEntryForm((form) => ({ ...form, time: e.target.value }))}
                      className="rounded-lg bg-ctp-surface1 px-3 py-2 text-sm text-ctp-text outline-none focus:ring-2 focus:ring-ctp-blue"
                    />
                  )}
                </div>
              )}

              {entryKind === "medication_dose" && (
                <>
                  <select
                    aria-label="Medication"
                    required
                    value={entryForm.medicationId}
                    onChange={(e) => {
                      const medication = medicationById[Number(e.target.value)];
                      setEntryForm((form) => ({
                        ...form,
                        medicationId: e.target.value,
                        doseMg: medication ? medicationDefaultDose(medication) : form.doseMg,
                        doseType: medication?.is_prn ? "prn" : "scheduled",
                      }));
                    }}
                    className="rounded-lg bg-ctp-surface1 px-3 py-2 text-sm text-ctp-text outline-none focus:ring-2 focus:ring-ctp-blue"
                  >
                    <option value="" disabled>
                      Select medication
                    </option>
                    {activeMedications.map((medication) => (
                      <option key={medication.id} value={medication.id}>
                        {medication.name}
                      </option>
                    ))}
                  </select>
                  <div className="grid grid-cols-2 gap-2">
                    <input
                      aria-label="Dose amount"
                      type="number"
                      min="0"
                      step="0.001"
                      required
                      value={entryForm.doseMg}
                      onChange={(e) => setEntryForm((form) => ({ ...form, doseMg: e.target.value }))}
                      className="rounded-lg bg-ctp-surface1 px-3 py-2 text-sm text-ctp-text placeholder:text-ctp-overlay0 outline-none focus:ring-2 focus:ring-ctp-blue"
                      placeholder={`Dose ${selectedEntryMedication()?.dose_unit ?? "mg"}`}
                    />
                    <select
                      aria-label="Dose type"
                      value={entryForm.doseType}
                      onChange={(e) => setEntryForm((form) => ({ ...form, doseType: e.target.value as DoseType }))}
                      className="rounded-lg bg-ctp-surface1 px-3 py-2 text-sm text-ctp-text outline-none focus:ring-2 focus:ring-ctp-blue"
                    >
                      <option value={selectedEntryMedication()?.is_prn ? "prn" : "scheduled"}>
                        {selectedEntryMedication()?.is_prn ? "PRN" : "Scheduled"}
                      </option>
                      {!selectedEntryMedication()?.is_prn && <option value="missed">Missed</option>}
                      <option value="reconciliation">Reconciliation</option>
                    </select>
                  </div>
                  <select
                    aria-label="Dose timing context"
                    value={entryForm.doseTimingContext}
                    onChange={(e) => setEntryForm((form) => ({
                      ...form,
                      doseTimingContext: e.target.value as "wake" | "sleep" | "other",
                    }))}
                    className="rounded-lg bg-ctp-surface1 px-3 py-2 text-sm text-ctp-text outline-none focus:ring-2 focus:ring-ctp-blue"
                  >
                    <option value="other">No timing context</option>
                    <option value="wake">Wake meds</option>
                    <option value="sleep">Sleep meds</option>
                  </select>
                </>
              )}

              {entryKind === "blood_pressure" && (
                <>
                  <select
                    aria-label="Reading context"
                    value={entryForm.readingContext}
                    onChange={(e) => setEntryForm((form) => ({ ...form, readingContext: e.target.value as "wake" | "sleep" }))}
                    className="rounded-lg bg-ctp-surface1 px-3 py-2 text-sm text-ctp-text outline-none focus:ring-2 focus:ring-ctp-blue"
                  >
                    <option value="wake">Wake</option>
                    <option value="sleep">Sleep</option>
                  </select>
                  <div className="grid grid-cols-3 gap-2">
                    <input
                      aria-label="Systolic"
                      type="number"
                      required
                      value={entryForm.systolic}
                      onChange={(e) => setEntryForm((form) => ({ ...form, systolic: e.target.value }))}
                      className="rounded-lg bg-ctp-surface1 px-3 py-2 text-sm text-ctp-text placeholder:text-ctp-overlay0 outline-none focus:ring-2 focus:ring-ctp-blue"
                      placeholder="Sys"
                    />
                    <input
                      aria-label="Diastolic"
                      type="number"
                      required
                      value={entryForm.diastolic}
                      onChange={(e) => setEntryForm((form) => ({ ...form, diastolic: e.target.value }))}
                      className="rounded-lg bg-ctp-surface1 px-3 py-2 text-sm text-ctp-text placeholder:text-ctp-overlay0 outline-none focus:ring-2 focus:ring-ctp-blue"
                      placeholder="Dia"
                    />
                    <input
                      aria-label="Heart rate"
                      type="number"
                      value={entryForm.pulse}
                      onChange={(e) => setEntryForm((form) => ({ ...form, pulse: e.target.value }))}
                      className="rounded-lg bg-ctp-surface1 px-3 py-2 text-sm text-ctp-text placeholder:text-ctp-overlay0 outline-none focus:ring-2 focus:ring-ctp-blue"
                      placeholder="HR"
                    />
                  </div>
                </>
              )}

              {entryKind === "weight" && (
                <input
                  aria-label="Weight in pounds"
                  type="number"
                  min="0"
                  step="0.1"
                  required
                  value={entryForm.weight}
                  onChange={(e) => setEntryForm((form) => ({ ...form, weight: e.target.value }))}
                  className="rounded-lg bg-ctp-surface1 px-3 py-2 text-sm text-ctp-text placeholder:text-ctp-overlay0 outline-none focus:ring-2 focus:ring-ctp-blue"
                  placeholder="Weight in lb"
                />
              )}

              {entryKind === "sleep" && (
                <>
                  <div className="grid grid-cols-2 gap-2">
                    <input
                      aria-label="Bedtime"
                      type="time"
                      required
                      value={entryForm.bedtime}
                      onChange={(e) => setEntryForm((form) => ({ ...form, bedtime: e.target.value }))}
                      className="rounded-lg bg-ctp-surface1 px-3 py-2 text-sm text-ctp-text outline-none focus:ring-2 focus:ring-ctp-blue"
                    />
                    <input
                      aria-label="Wake time"
                      type="time"
                      required
                      value={entryForm.wakeTime}
                      onChange={(e) => setEntryForm((form) => ({ ...form, wakeTime: e.target.value }))}
                      className="rounded-lg bg-ctp-surface1 px-3 py-2 text-sm text-ctp-text outline-none focus:ring-2 focus:ring-ctp-blue"
                    />
                  </div>
                  <input
                    aria-label="Sleep minutes"
                    type="number"
                    min="1"
                    step="1"
                    value={entryForm.sleepMinutes}
                    onChange={(e) => setEntryForm((form) => ({ ...form, sleepMinutes: e.target.value }))}
                    className="rounded-lg bg-ctp-surface1 px-3 py-2 text-sm text-ctp-text placeholder:text-ctp-overlay0 outline-none focus:ring-2 focus:ring-ctp-blue"
                    placeholder="Sleep minutes from tracker"
                  />
                </>
              )}

              {entryKind === "steps" && (
                <input
                  aria-label="Steps"
                  type="number"
                  min="0"
                  step="1"
                  required
                  value={entryForm.steps}
                  onChange={(e) => setEntryForm((form) => ({ ...form, steps: e.target.value }))}
                  className="rounded-lg bg-ctp-surface1 px-3 py-2 text-sm text-ctp-text placeholder:text-ctp-overlay0 outline-none focus:ring-2 focus:ring-ctp-blue"
                  placeholder="Steps"
                />
              )}

              <button
                type="submit"
                disabled={savingEntry}
                className="mt-1 rounded-lg bg-[#89b4fa] px-4 py-2 text-sm font-medium text-[#1e1e2e] transition hover:bg-[#74c7ec] disabled:opacity-50"
              >
                {savingEntry
                  ? "Saving..."
                  : editingEvent
                    ? "Save correction"
                    : entryKind === "new_medication" && medicationAdminTarget
                      ? "Update medication"
                      : "Save"}
              </button>
            </div>
          </form>
        </div>
      )}

      {editOpen && (
        <div className="fixed inset-0 z-50 flex items-end bg-black/70 p-0 sm:items-center sm:justify-center sm:p-6">
          <section className="max-h-[92vh] w-full overflow-y-auto rounded-t-xl border border-ctp-surface0 bg-ctp-base p-4 shadow-xl sm:max-w-2xl sm:rounded-xl sm:p-5">
            <div className="mb-4 flex items-center justify-between gap-4">
              <h3 className="text-lg font-medium text-ctp-text">Edit records</h3>
              <button
                type="button"
                onClick={() => setEditOpen(false)}
                className="rounded-lg border border-ctp-surface1 px-3 py-1.5 text-sm text-ctp-subtext1 hover:text-ctp-text"
              >
                Close
              </button>
            </div>

            <div className="divide-y divide-ctp-surface0 overflow-hidden rounded-lg border border-ctp-surface0">
              {editableEvents.length === 0 && (
                <p className="px-4 py-5 text-center text-sm text-ctp-overlay0">No records yet.</p>
              )}
              {editableEvents.slice(0, 30).map((event) => (
                <button
                  key={event.id}
                  type="button"
                  onClick={() => openEditModal(event)}
                  className="flex w-full items-center justify-between gap-4 bg-ctp-base px-4 py-3 text-left transition hover:bg-ctp-mantle"
                >
                  <span>
                    <span className="block text-sm font-medium text-ctp-text">{recordLabel(event)}</span>
                    <span className="mt-1 block text-xs text-ctp-overlay0">{formatDateTime(event.recorded_at)}</span>
                  </span>
                  <span className="text-sm text-ctp-blue">Edit</span>
                </button>
              ))}
            </div>
          </section>
        </div>
      )}

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
