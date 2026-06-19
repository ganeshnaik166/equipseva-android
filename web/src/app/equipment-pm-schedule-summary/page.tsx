import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Equipment PM schedule summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_scheduled: number;
  upcoming_count: number;
  due_count: number;
  overdue_count: number;
  completed_count: number;
  cancelled_count: number;
  due_next_7d: number;
  due_next_30d: number;
  overdue_gt_30d: number;
  distinct_equipment_types: number;
  distinct_hospitals: number;
  reminders_sent_30d: number;
  prequotes_sent_30d: number;
  active_intervals_seeded: number;
};

function Kpi({ label, value, tone }: { label: string; value: string; tone?: "ok" | "warn" | "danger" | "muted" }) {
  const color =
    tone === "ok" ? "text-[var(--color-ok)]" :
    tone === "warn" ? "text-[var(--color-warn)]" :
    tone === "danger" ? "text-[var(--color-danger)]" :
    tone === "muted" ? "text-[var(--color-muted)]" :
    "";
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-[10px] uppercase tracking-wide text-[var(--color-muted)]">{label}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${color}`}>{value}</div>
    </div>
  );
}

export default async function EquipmentPmScheduleSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_equipment_pm_schedule_summary");
  if (error) throw new Error(`founder_equipment_pm_schedule_summary: ${error.message}`);
  const r = ((data ?? [])[0] ?? {
    total_scheduled: 0, upcoming_count: 0, due_count: 0, overdue_count: 0,
    completed_count: 0, cancelled_count: 0, due_next_7d: 0, due_next_30d: 0,
    overdue_gt_30d: 0, distinct_equipment_types: 0, distinct_hospitals: 0,
    reminders_sent_30d: 0, prequotes_sent_30d: 0, active_intervals_seeded: 0,
  }) as Row;

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Equipment PM schedule summary</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Fleet-wide preventive-maintenance plan · upcoming / overdue / breadth / reminder reach
        </span>
      </header>

      <section>
        <h2 className="mb-2 text-xs uppercase tracking-wide text-[var(--color-muted)]">Status mix</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6">
          <Kpi label="Total scheduled" value={formatNumber(Number(r.total_scheduled))} />
          <Kpi label="Upcoming" value={formatNumber(Number(r.upcoming_count))} />
          <Kpi label="Due" value={formatNumber(Number(r.due_count))} tone="warn" />
          <Kpi label="Overdue" value={formatNumber(Number(r.overdue_count))} tone="danger" />
          <Kpi label="Completed" value={formatNumber(Number(r.completed_count))} tone="ok" />
          <Kpi label="Cancelled" value={formatNumber(Number(r.cancelled_count))} tone="muted" />
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-xs uppercase tracking-wide text-[var(--color-muted)]">Time windows</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
          <Kpi label="Due next 7 days" value={formatNumber(Number(r.due_next_7d))} tone="warn" />
          <Kpi label="Due next 30 days" value={formatNumber(Number(r.due_next_30d))} />
          <Kpi label="Overdue > 30 days" value={formatNumber(Number(r.overdue_gt_30d))} tone="danger" />
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-xs uppercase tracking-wide text-[var(--color-muted)]">Breadth & reach</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5">
          <Kpi label="Equipment types" value={formatNumber(Number(r.distinct_equipment_types))} />
          <Kpi label="Hospitals on plan" value={formatNumber(Number(r.distinct_hospitals))} />
          <Kpi label="Reminders sent 30d" value={formatNumber(Number(r.reminders_sent_30d))} />
          <Kpi label="Pre-quotes sent 30d" value={formatNumber(Number(r.prequotes_sent_30d))} />
          <Kpi label="Active intervals seeded" value={formatNumber(Number(r.active_intervals_seeded))} tone="muted" />
        </div>
      </section>

      <p className="text-[11px] text-[var(--color-muted)]">
        PM schedule = the <em>plan</em> (forward calendar from equipment_pm_schedule). Distinct from
        amc-visits-cadence which measures actual executed visits. Drives proactive assignment + AMC value demo.
      </p>
    </div>
  );
}
