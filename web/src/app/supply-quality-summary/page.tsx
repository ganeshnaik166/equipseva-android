import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Supply quality summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_engineers: number;
  verified_pct: number;
  kyc_pending_over_7d: number;
  tier_gold_pct: number;
  tier_silver_pct: number;
  tier_none_pct: number;
  avg_audit_rating_30d: number;
  audit_pass_pct_30d: number;
  avg_payout_success_pct_30d: number;
  avg_jobs_per_active_30d: number;
  engineers_no_jobs_90d_pct: number;
  disputes_against_engineers_30d: number;
  composite_supply_score: number;
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

const pct = (n: number) => `${Number(n).toFixed(1)}%`;

export default async function SupplyQualitySummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_supply_quality_summary");
  if (error) throw new Error(`founder_supply_quality_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Supply quality summary</h1>
        <span className="text-xs text-[var(--color-muted)]">Composite engineer-trust score · KYC + tiers + audit + payouts + activity</span>
      </header>
      {r ? (
        <>
          <div className={`rounded-lg border-2 p-6 ${r.composite_supply_score >= 75 ? "border-[var(--color-ok)]" : r.composite_supply_score >= 60 ? "border-[var(--color-warn)]" : "border-[var(--color-danger)]"} bg-[var(--color-surface)]`}>
            <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">Composite supply quality score</div>
            <div className="mt-2 text-4xl font-bold tabular-nums">{pct(r.composite_supply_score)}</div>
            <div className="mt-1 text-xs text-[var(--color-muted)]">avg(verified % + audit pass % + payout success % + active 30d %)</div>
          </div>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
            <Card title="Total engineers" val={formatNumber(r.total_engineers)} />
            <Card title="Verified" val={pct(r.verified_pct)} ok={r.verified_pct >= 80} sub="KYC complete" />
            <Card title="KYC pending >7d" val={formatNumber(r.kyc_pending_over_7d)} danger={r.kyc_pending_over_7d > 0} />
            <Card title="Tier gold" val={pct(r.tier_gold_pct)} ok />
            <Card title="Tier silver" val={pct(r.tier_silver_pct)} />
            <Card title="Tier none" val={pct(r.tier_none_pct)} sub="no certified jobs" />
            <Card title="Avg audit rating 30d" val={Number(r.avg_audit_rating_30d).toFixed(2)} ok={r.avg_audit_rating_30d >= 4.0} sub="5★ scale" />
            <Card title="Audit pass % 30d" val={pct(r.audit_pass_pct_30d)} ok={r.audit_pass_pct_30d >= 80} sub="rating ≥4" />
            <Card title="Payout success % 30d" val={pct(r.avg_payout_success_pct_30d)} ok={r.avg_payout_success_pct_30d >= 95} />
            <Card title="Avg jobs / active 30d" val={Number(r.avg_jobs_per_active_30d).toFixed(2)} sub="throughput density" />
            <Card title="No jobs 90d" val={pct(r.engineers_no_jobs_90d_pct)} danger={r.engineers_no_jobs_90d_pct > 50} sub="of total engineers" />
            <Card title="Disputes vs eng 30d" val={formatNumber(r.disputes_against_engineers_30d)} danger={r.disputes_against_engineers_30d > 0} sub="hospital-filed" />
          </div>
        </>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
