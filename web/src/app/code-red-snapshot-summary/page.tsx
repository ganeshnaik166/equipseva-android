import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Code Red snapshot summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_all_time: number;
  open_now: number;
  stuck_over_4h: number;
  resolved_30d: number;
  timed_out_30d: number;
  sla_breach_30d: number;
  sla_breach_pct_30d: number;
  created_today: number;
  resolved_today: number;
  active_hospitals_30d: number;
  responders_30d: number;
  avg_resolve_minutes_30d: number;
  avg_ceiling_inr_30d: number;
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

export default async function CodeRedSnapshotSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_code_red_snapshot_summary");
  if (error) throw new Error(`founder_code_red_snapshot_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Code Red snapshot summary</h1>
        <span className="text-xs text-[var(--color-muted)]">13-KPI emergency dashboard · today/30d/all-time · SLA breach % · pair with /code-red-index</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Total Code Red all-time" val={formatNumber(r.total_all_time)} />
          <Card title="Open now" val={formatNumber(r.open_now)} danger={r.open_now > 0} sub="unresolved + unaccepted" />
          <Card title="Stuck >4h" val={formatNumber(r.stuck_over_4h)} danger={r.stuck_over_4h > 0} />
          <Card title="Resolved 30d" val={formatNumber(r.resolved_30d)} ok />
          <Card title="Timed-out 30d" val={formatNumber(r.timed_out_30d)} danger={r.timed_out_30d > 0} />
          <Card title="SLA breach 30d" val={formatNumber(r.sla_breach_30d)} danger={r.sla_breach_30d > 0} sub={`${Number(r.sla_breach_pct_30d).toFixed(1)}% of resolved`} />
          <Card title="Created today" val={formatNumber(r.created_today)} />
          <Card title="Resolved today" val={formatNumber(r.resolved_today)} ok />
          <Card title="Active hospitals 30d" val={formatNumber(r.active_hospitals_30d)} />
          <Card title="Responders 30d" val={formatNumber(r.responders_30d)} sub="distinct engineers accepted" />
          <Card title="Avg resolve mins 30d" val={Number(r.avg_resolve_minutes_30d).toFixed(1)} sub="SLA target ≤60min" />
          <Card title="Avg ceiling INR 30d" val={`₹${Number(r.avg_ceiling_inr_30d).toLocaleString("en-IN")}`} sub="hospital max-fee offered" />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
