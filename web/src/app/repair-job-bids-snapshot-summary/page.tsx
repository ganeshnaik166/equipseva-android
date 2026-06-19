import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Repair job bids snapshot summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_all_time: number;
  pending_now: number;
  accepted_30d: number;
  rejected_30d: number;
  withdrawn_30d: number;
  acceptance_pct_30d: number;
  active_engineers_30d: number;
  avg_amount_30d_inr: number;
  max_amount_30d_inr: number;
  created_today: number;
  accepted_today: number;
  avg_bids_per_open_job: number;
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

const inr = (n: number) => `₹${Number(n).toLocaleString("en-IN")}`;

export default async function RepairJobBidsSnapshotSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_repair_job_bids_snapshot_summary");
  if (error) throw new Error(`founder_repair_job_bids_snapshot_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Repair job bids snapshot summary</h1>
        <span className="text-xs text-[var(--color-muted)]">12-KPI bid dynamics · acceptance % + engineer competition + per-open-job density</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Total bids all-time" val={formatNumber(r.total_all_time)} />
          <Card title="Pending now" val={formatNumber(r.pending_now)} />
          <Card title="Accepted 30d" val={formatNumber(r.accepted_30d)} ok />
          <Card title="Acceptance % 30d" val={`${Number(r.acceptance_pct_30d).toFixed(1)}%`} ok={r.acceptance_pct_30d >= 30} sub="accepted / settled" />
          <Card title="Rejected 30d" val={formatNumber(r.rejected_30d)} sub="hospital filtered" />
          <Card title="Withdrawn 30d" val={formatNumber(r.withdrawn_30d)} sub="engineer pulled" />
          <Card title="Active engineers 30d" val={formatNumber(r.active_engineers_30d)} sub="placed ≥1 bid" />
          <Card title="Avg bid amount 30d" val={inr(r.avg_amount_30d_inr)} />
          <Card title="Max bid amount 30d" val={inr(r.max_amount_30d_inr)} />
          <Card title="Avg bids / open job" val={Number(r.avg_bids_per_open_job).toFixed(2)} sub="marketplace competitiveness" />
          <Card title="Bids placed today" val={formatNumber(r.created_today)} />
          <Card title="Bids accepted today" val={formatNumber(r.accepted_today)} ok />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
