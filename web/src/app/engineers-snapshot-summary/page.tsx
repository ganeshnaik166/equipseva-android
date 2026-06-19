import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Engineers snapshot summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_all_time: number;
  verified_cnt: number;
  pending_kyc_cnt: number;
  pending_kyc_over_7d: number;
  tier_gold: number;
  tier_silver: number;
  tier_bronze: number;
  tier_none: number;
  active_30d: number;
  active_7d: number;
  paid_30d: number;
  new_signups_30d: number;
  new_signups_today: number;
  avg_jobs_per_active_30d: number;
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

export default async function EngineersSnapshotSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_engineers_snapshot_summary");
  if (error) throw new Error(`founder_engineers_snapshot_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Engineers snapshot summary</h1>
        <span className="text-xs text-[var(--color-muted)]">14-KPI supply dashboard · KYC + tiers + activity · pair with /engineers-index</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Total engineers all-time" val={formatNumber(r.total_all_time)} />
          <Card title="Verified" val={formatNumber(r.verified_cnt)} ok />
          <Card title="Pending KYC" val={formatNumber(r.pending_kyc_cnt)} sub="onboarding queue" />
          <Card title="Pending KYC >7d" val={formatNumber(r.pending_kyc_over_7d)} danger={r.pending_kyc_over_7d > 0} sub="abandoned signal" />
          <Card title="Tier: Gold" val={formatNumber(r.tier_gold)} ok />
          <Card title="Tier: Silver" val={formatNumber(r.tier_silver)} />
          <Card title="Tier: Bronze" val={formatNumber(r.tier_bronze)} />
          <Card title="Tier: None" val={formatNumber(r.tier_none)} sub="no certified jobs yet" />
          <Card title="Active 30d" val={formatNumber(r.active_30d)} sub="completed ≥1 job" />
          <Card title="Active 7d" val={formatNumber(r.active_7d)} />
          <Card title="Paid 30d" val={formatNumber(r.paid_30d)} sub="received payout" />
          <Card title="New signups 30d" val={formatNumber(r.new_signups_30d)} />
          <Card title="New signups today" val={formatNumber(r.new_signups_today)} />
          <Card title="Avg jobs / active 30d" val={Number(r.avg_jobs_per_active_30d).toFixed(2)} />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
