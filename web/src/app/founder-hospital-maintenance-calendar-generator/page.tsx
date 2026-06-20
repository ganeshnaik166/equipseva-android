import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Hospital maintenance calendar generator — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  total_rows: number;
  scheduled_count: number;
  assigned_count: number;
  in_progress_count: number;
  completed_count: number;
  rescheduled_count: number;
  cancelled_count: number;
  overdue_count: number;
  due_next_7d: number;
  due_next_30d: number;
  due_next_90d: number;
  preventive_count: number;
  calibration_count: number;
  active_amcs_covered: number;
  avg_expected_minutes: number;
  total_expected_hours: number;
};

type ScheduleRow = {
  id: string;
  amc_contract_id: string;
  equipment_label: string;
  scheduled_date: string;
  visit_kind: string;
  status: string;
  expected_minutes: number;
  assigned_engineer_id: string | null;
  amc_tier: string | null;
  hospital_name: string;
  days_until: number;
  is_overdue: boolean;
  created_at: string;
};

type OverdueRow = {
  id: string;
  equipment_label: string;
  scheduled_date: string;
  visit_kind: string;
  status: string;
  days_overdue: number;
  hospital_name: string;
  amc_tier: string | null;
};

function fmtDate(d: string) {
  if (!d) return "";
  return new Date(d).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "2-digit" });
}

function statusColor(s: string) {
  if (s === "completed") return "text-[var(--color-ok)]";
  if (s === "in_progress" || s === "assigned") return "text-[var(--color-info)]";
  if (s === "cancelled") return "text-[var(--color-muted)]";
  if (s === "rescheduled") return "text-[var(--color-warn)]";
  return "text-[var(--color-fg)]";
}

export default async function FounderHospitalMaintenanceCalendarGeneratorPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [summaryRes, recentRes, overdueRes] = await Promise.all([
    supabase.rpc("founder_hospital_maintenance_calendar_summary"),
    supabase.rpc("founder_hospital_maintenance_calendar_recent"),
    supabase.rpc("founder_hospital_maintenance_calendar_overdue"),
  ]);

  if (summaryRes.error) throw new Error(`summary: ${summaryRes.error.message}`);
  if (recentRes.error) throw new Error(`recent: ${recentRes.error.message}`);
  if (overdueRes.error) throw new Error(`overdue: ${overdueRes.error.message}`);

  const summary = ((summaryRes.data ?? [])[0] ?? {
    total_rows: 0, scheduled_count: 0, assigned_count: 0, in_progress_count: 0,
    completed_count: 0, rescheduled_count: 0, cancelled_count: 0, overdue_count: 0,
    due_next_7d: 0, due_next_30d: 0, due_next_90d: 0, preventive_count: 0,
    calibration_count: 0, active_amcs_covered: 0, avg_expected_minutes: 0, total_expected_hours: 0,
  }) as Summary;

  const recent = (recentRes.data ?? []) as ScheduleRow[];
  const overdue = (overdueRes.data ?? []) as OverdueRow[];

  const cards: { label: string; value: string; tone?: string }[] = [
    { label: "Total schedule rows", value: formatNumber(summary.total_rows) },
    { label: "Active AMCs covered", value: formatNumber(summary.active_amcs_covered) },
    { label: "Scheduled", value: formatNumber(summary.scheduled_count) },
    { label: "Assigned", value: formatNumber(summary.assigned_count), tone: "text-[var(--color-info)]" },
    { label: "In progress", value: formatNumber(summary.in_progress_count), tone: "text-[var(--color-info)]" },
    { label: "Completed", value: formatNumber(summary.completed_count), tone: "text-[var(--color-ok)]" },
    { label: "Rescheduled", value: formatNumber(summary.rescheduled_count), tone: "text-[var(--color-warn)]" },
    { label: "Cancelled", value: formatNumber(summary.cancelled_count), tone: "text-[var(--color-muted)]" },
    { label: "Overdue", value: formatNumber(summary.overdue_count), tone: "text-[var(--color-danger)]" },
    { label: "Due next 7d", value: formatNumber(summary.due_next_7d) },
    { label: "Due next 30d", value: formatNumber(summary.due_next_30d) },
    { label: "Due next 90d", value: formatNumber(summary.due_next_90d) },
    { label: "Preventive", value: formatNumber(summary.preventive_count) },
    { label: "Calibration", value: formatNumber(summary.calibration_count) },
    { label: "Avg minutes / visit", value: formatNumber(Math.round(Number(summary.avg_expected_minutes) || 0)) },
    { label: "Total expected hours", value: formatNumber(Math.round(Number(summary.total_expected_hours) || 0)) },
  ];

  const cols: Column<ScheduleRow>[] = [
    {
      key: "date",
      header: "Date",
      render: (r) => (
        <span className={`text-xs tabular-nums ${r.is_overdue ? "text-[var(--color-danger)] font-medium" : ""}`}>
          {fmtDate(r.scheduled_date)}
        </span>
      ),
    },
    {
      key: "due",
      header: "Days",
      render: (r) => (
        <span className="text-xs tabular-nums text-[var(--color-muted)]">
          {r.days_until > 0 ? `+${r.days_until}` : r.days_until}
        </span>
      ),
    },
    { key: "hospital", header: "Hospital", render: (r) => <span className="text-xs">{r.hospital_name}</span> },
    {
      key: "tier",
      header: "Tier",
      render: (r) => <span className="text-xs uppercase tracking-wide text-[var(--color-muted)]">{r.amc_tier ?? "-"}</span>,
    },
    {
      key: "equip",
      header: "Equipment",
      render: (r) => <span className="text-xs">{r.equipment_label}</span>,
    },
    {
      key: "kind",
      header: "Visit kind",
      render: (r) => <span className="text-xs uppercase tracking-wide">{r.visit_kind}</span>,
    },
    {
      key: "status",
      header: "Status",
      render: (r) => (
        <span className={`text-xs font-medium uppercase tracking-wide ${statusColor(r.status)}`}>{r.status}</span>
      ),
    },
    {
      key: "mins",
      header: "Min",
      render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.expected_minutes)}</span>,
    },
    {
      key: "eng",
      header: "Eng",
      render: (r) => (
        <span className="text-xs text-[var(--color-muted)]">{r.assigned_engineer_id ? "assigned" : "-"}</span>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Hospital maintenance calendar generator</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Auto-generated maintenance schedule rows from active AMCs · 90d forward window · 1/month proxy
        </span>
      </header>

      {summary.overdue_count > 0 ? (
        <div className="rounded border border-[var(--color-danger)] bg-[var(--color-danger-bg,transparent)] p-3">
          <div className="text-xs font-semibold uppercase tracking-wide text-[var(--color-danger)]">
            Overdue maintenance: {formatNumber(summary.overdue_count)}
          </div>
          <div className="mt-1 text-xs text-[var(--color-muted)]">
            {overdue.length > 0
              ? `Oldest: ${overdue[0].hospital_name} · ${overdue[0].equipment_label} · ${overdue[0].days_overdue}d late`
              : "Run engineer-assignment sweep."}
          </div>
        </div>
      ) : null}

      <section>
        <h2 className="mb-3 text-sm font-medium uppercase tracking-wide text-[var(--color-muted)]">
          Schedule KPIs · 16 cards
        </h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4 lg:grid-cols-4">
          {cards.map((c) => (
            <div key={c.label} className="rounded border border-[var(--color-border)] p-3">
              <div className="text-[10px] uppercase tracking-wide text-[var(--color-muted)]">{c.label}</div>
              <div className={`mt-1 text-lg font-semibold tabular-nums ${c.tone ?? ""}`}>{c.value}</div>
            </div>
          ))}
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-sm font-medium uppercase tracking-wide text-[var(--color-muted)]">
          Schedule ledger · 100 rows · soonest first
        </h2>
        <DataTable
          columns={cols}
          rows={recent}
          rowKey={(r) => r.id}
          emptyMessage="No schedule rows yet. Run founder_hospital_maintenance_calendar_generate_quarter() to seed."
        />
      </section>
    </div>
  );
}
