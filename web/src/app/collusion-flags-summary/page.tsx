import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Collusion flags summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_all_time: number;
  open_now: number;
  investigating_now: number;
  confirmed_all_time: number;
  false_positive_all_time: number;
  resolved_all_time: number;
  unreviewed_over_7d: number;
  oldest_unreviewed_age_hours: number;
  distinct_engineers_flagged: number;
  distinct_hospitals_flagged: number;
  closed_loop_pair_open: number;
  shared_ip_signature_open: number;
  bid_amount_clustering_open: number;
  open_money_at_stake_inr: number;
  created_today: number;
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

export default async function CollusionFlagsSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_collusion_flags_summary");
  if (error) throw new Error(`founder_collusion_flags_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Collusion flags summary</h1>
        <span className="text-xs text-[var(--color-muted)]">15-KPI pre-emptive fraud dashboard · engineer-hospital collusion signals · pair with /open-disputes</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Total flags all-time" val={formatNumber(r.total_all_time)} sub="signals ever raised" />
          <Card title="Open now" val={formatNumber(r.open_now)} danger={r.open_now > 0} sub="awaiting triage" />
          <Card title="Investigating now" val={formatNumber(r.investigating_now)} danger={r.investigating_now > 0} sub="under review" />
          <Card title="Unreviewed >7d" val={formatNumber(r.unreviewed_over_7d)} danger={r.unreviewed_over_7d > 0} sub="SLA breach" />
          <Card title="Oldest unreviewed (hrs)" val={Number(r.oldest_unreviewed_age_hours).toFixed(1)} danger={r.oldest_unreviewed_age_hours > 168} sub="open + investigating" />
          <Card title="Confirmed all-time" val={formatNumber(r.confirmed_all_time)} danger={r.confirmed_all_time > 0} sub="real collusion" />
          <Card title="False positive all-time" val={formatNumber(r.false_positive_all_time)} sub="cleared" />
          <Card title="Resolved all-time" val={formatNumber(r.resolved_all_time)} ok sub="closed out" />
          <Card title="Distinct engineers flagged" val={formatNumber(r.distinct_engineers_flagged)} sub="active flag set" />
          <Card title="Distinct hospitals flagged" val={formatNumber(r.distinct_hospitals_flagged)} sub="active flag set" />
          <Card title="Closed-loop pair (open)" val={formatNumber(r.closed_loop_pair_open)} danger={r.closed_loop_pair_open > 0} sub=">3 jobs/30d, no others" />
          <Card title="Shared IP signature (open)" val={formatNumber(r.shared_ip_signature_open)} danger={r.shared_ip_signature_open > 0} sub="auth IP overlap" />
          <Card title="Bid clustering (open)" val={formatNumber(r.bid_amount_clustering_open)} danger={r.bid_amount_clustering_open > 0} sub="bids ±5%" />
          <Card title="Open money at stake" val={inr(r.open_money_at_stake_inr)} danger={r.open_money_at_stake_inr > 0} sub="30d value · open flags" />
          <Card title="Created today" val={formatNumber(r.created_today)} sub="IST day" />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
