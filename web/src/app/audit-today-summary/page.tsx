import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber, formatRelativeTime } from "@/lib/format";

export const metadata = { title: "Audit today summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_today: number;
  success_today: number;
  failed_today: number;
  distinct_actors: number;
  distinct_ops: number;
  distinct_tables: number;
  first_action_at: string | null;
  last_action_at: string | null;
};

function Card({ title, val, sub, danger }: { title: string; val: string; sub?: string; danger?: boolean }) {
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs text-[var(--color-muted)]">{title}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${danger ? "text-[var(--color-danger)]" : ""}`}>{val}</div>
      {sub ? <div className="text-xs tabular-nums text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

export default async function AuditTodaySummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_audit_today_summary");
  if (error) throw new Error(`founder_audit_today_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Audit today summary</h1>
        <span className="text-xs text-[var(--color-muted)]">Founder/admin actions today (IST) · daily governance pulse</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Total ops today" val={formatNumber(r.total_today)} />
          <Card title="Success" val={formatNumber(r.success_today)} sub={r.total_today > 0 ? `${Math.round(100 * r.success_today / r.total_today)}%` : undefined} />
          <Card title="Failed" val={formatNumber(r.failed_today)} danger={r.failed_today > 0} sub={r.total_today > 0 ? `${Math.round(100 * r.failed_today / r.total_today)}%` : undefined} />
          <Card title="Distinct actors" val={formatNumber(r.distinct_actors)} />
          <Card title="Distinct ops" val={formatNumber(r.distinct_ops)} />
          <Card title="Distinct tables" val={formatNumber(r.distinct_tables)} />
          <Card title="First action" val={r.first_action_at ? formatRelativeTime(r.first_action_at) : "—"} />
          <Card title="Last action" val={r.last_action_at ? formatRelativeTime(r.last_action_at) : "—"} />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
