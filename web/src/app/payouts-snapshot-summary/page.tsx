import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Payouts snapshot summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_all_time: number;
  queued_now: number;
  queued_inr_now: number;
  processing_now: number;
  processed_30d: number;
  processed_inr_30d: number;
  failed_30d: number;
  failed_inr_30d: number;
  stuck_over_7d: number;
  stuck_inr_over_7d: number;
  distinct_engs_paid_30d: number;
  avg_amount_30d: number;
  queued_today: number;
  processed_today: number;
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

export default async function PayoutsSnapshotSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_payouts_snapshot_summary");
  if (error) throw new Error(`founder_payouts_snapshot_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Payouts snapshot summary</h1>
        <span className="text-xs text-[var(--color-muted)]">14-KPI payouts pipeline · today/30d/all-time · pair with /payouts-index</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Total payouts all-time" val={formatNumber(r.total_all_time)} />
          <Card title="Queued now" val={formatNumber(r.queued_now)} sub={inr(r.queued_inr_now)} />
          <Card title="Processing now" val={formatNumber(r.processing_now)} />
          <Card title="Processed 30d" val={formatNumber(r.processed_30d)} ok sub={inr(r.processed_inr_30d)} />
          <Card title="Failed 30d" val={formatNumber(r.failed_30d)} danger={r.failed_30d > 0} sub={inr(r.failed_inr_30d)} />
          <Card title="Stuck >7d" val={formatNumber(r.stuck_over_7d)} danger={r.stuck_over_7d > 0} sub={inr(r.stuck_inr_over_7d)} />
          <Card title="Engineers paid 30d" val={formatNumber(r.distinct_engs_paid_30d)} sub="distinct" />
          <Card title="Avg amount 30d" val={inr(r.avg_amount_30d)} />
          <Card title="Queued today" val={formatNumber(r.queued_today)} />
          <Card title="Processed today" val={formatNumber(r.processed_today)} ok />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
