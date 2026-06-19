import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Engineer KYC renewals summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  renewals_total: number;
  status_pending: number;
  status_in_progress: number;
  status_completed: number;
  status_expired: number;
  status_waived: number;
  due_next_7d: number;
  due_next_30d: number;
  overdue_in_grace: number;
  oldest_pending_days: number;
  avg_completion_days_30d: number;
  scheduled_today: number;
  completed_today: number;
  expired_last_7d: number;
};

function Card({ title, val, sub, danger, ok }: { title: string; val: string; sub?: string; danger?: boolean; ok?: boolean }) {
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs text-[var(--color-muted)]">{title}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${danger ? "text-[var(--color-danger)]" : ok ? "text-[var(--color-ok)]" : ""}`}>{val}</div>
      {sub ? <div className="text-xs tabular-nums text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

export default async function EngineerKycRenewalsSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_engineer_kyc_renewals_summary");
  if (error) throw new Error(`founder_engineer_kyc_renewals_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Engineer KYC renewals summary</h1>
        <span className="text-xs text-[var(--color-muted)]">{`14-KPI annual re-KYC queue · status mix + due-window buckets + grace-overdue + oldest-pending + 30d completion velocity + IST-day intake/closure + 7d expiries`}</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Renewals total" val={formatNumber(r.renewals_total)} sub="lifetime cycles scheduled" />
          <Card title="Pending" val={formatNumber(r.status_pending)} danger={r.status_pending > 0} sub="engineer not started" />
          <Card title="In progress" val={formatNumber(r.status_in_progress)} sub="engineer refreshing items" />
          <Card title="Completed" val={formatNumber(r.status_completed)} ok={r.status_completed > 0} sub="lifetime re-verified" />
          <Card title="Expired" val={formatNumber(r.status_expired)} danger={r.status_expired > 0} sub="grace exceeded — reverted" />
          <Card title="Waived" val={formatNumber(r.status_waived)} sub="founder skip" />
          <Card title="Due next 7d" val={formatNumber(r.due_next_7d)} danger={r.due_next_7d > 0} sub="nudge window" />
          <Card title="Due next 30d" val={formatNumber(r.due_next_30d)} sub="rolling cohort" />
          <Card title="Overdue in grace" val={formatNumber(r.overdue_in_grace)} danger={r.overdue_in_grace > 0} sub="past due_at, still before reap" />
          <Card title="Oldest pending (d)" val={`${Number(r.oldest_pending_days).toFixed(2)}d`} danger={r.oldest_pending_days >= 30} sub="worst-case cycle age" />
          <Card title="Avg completion 30d (d)" val={`${Number(r.avg_completion_days_30d).toFixed(2)}d`} ok={r.avg_completion_days_30d > 0 && r.avg_completion_days_30d < 7} sub="engineer turnaround" />
          <Card title="Scheduled today" val={formatNumber(r.scheduled_today)} sub="IST day intake (cron)" />
          <Card title="Completed today" val={formatNumber(r.completed_today)} ok={r.completed_today > 0} sub="IST day re-verified" />
          <Card title="Expired last 7d" val={formatNumber(r.expired_last_7d)} danger={r.expired_last_7d > 0} sub="reaper attrition" />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
