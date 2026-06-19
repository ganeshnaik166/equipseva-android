import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Escrow snapshot summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_all_time: number;
  pending_payment_now: number;
  held_now: number;
  held_inr_now: number;
  in_dispute_now: number;
  in_dispute_inr_now: number;
  stuck_held_over_14d: number;
  stuck_inr_over_14d: number;
  released_30d: number;
  released_inr_30d: number;
  refunded_30d: number;
  refunded_inr_30d: number;
  refund_rate_pct_30d: number;
  scheduled_release_7d: number;
  scheduled_release_inr_7d: number;
  avg_amount_30d: number;
  created_30d: number;
  released_today: number;
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

export default async function EscrowSnapshotSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_escrow_snapshot_summary");
  if (error) throw new Error(`founder_escrow_snapshot_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Escrow snapshot summary</h1>
        <span className="text-xs text-[var(--color-muted)]">18-KPI escrow pipeline · held + released + refunded + scheduled · money-in-flight founder view</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Total escrows all-time" val={formatNumber(r.total_all_time)} />
          <Card title="Pending payment" val={formatNumber(r.pending_payment_now)} sub="paid_at NULL" />
          <Card title="Held now" val={formatNumber(r.held_now)} sub={inr(r.held_inr_now)} />
          <Card title="In dispute" val={formatNumber(r.in_dispute_now)} danger={r.in_dispute_now > 0} sub={inr(r.in_dispute_inr_now)} />
          <Card title="Stuck held >14d" val={formatNumber(r.stuck_held_over_14d)} danger={r.stuck_held_over_14d > 0} sub={inr(r.stuck_inr_over_14d)} />
          <Card title="Released 30d" val={formatNumber(r.released_30d)} ok sub={inr(r.released_inr_30d)} />
          <Card title="Refunded 30d" val={formatNumber(r.refunded_30d)} danger={r.refunded_30d > 0} sub={inr(r.refunded_inr_30d)} />
          <Card title="Refund rate 30d" val={`${Number(r.refund_rate_pct_30d).toFixed(1)}%`} sub="refunded / terminal" />
          <Card title="Scheduled release ≤7d" val={formatNumber(r.scheduled_release_7d)} sub={inr(r.scheduled_release_inr_7d)} />
          <Card title="Avg amount 30d" val={inr(r.avg_amount_30d)} />
          <Card title="Created 30d" val={formatNumber(r.created_30d)} />
          <Card title="Released today" val={formatNumber(r.released_today)} ok />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
