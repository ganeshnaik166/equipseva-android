import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Hospital chains snapshot summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_chains: number;
  active_chains: number;
  paused_chains: number;
  offboarded_chains: number;
  total_member_hospitals: number;
  avg_members_per_chain: number;
  members_with_active_amc: number;
  amc_coverage_pct: number;
  pending_invites: number;
  new_chains_30d: number;
  new_chains_today: number;
  chain_revenue_90d_rupees: number;
  chains_zero_amc_coverage: number;
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

export default async function HospitalChainsSnapshotSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_hospital_chains_snapshot_summary");
  if (error) throw new Error(`founder_hospital_chains_snapshot_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Hospital chains snapshot summary</h1>
        <span className="text-xs text-[var(--color-muted)]">13-KPI whale-account dashboard · chains / members / AMC coverage / 90d revenue · pair with /chains-leaderboard + /chains-amc-gap</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Total chains" val={formatNumber(r.total_chains)} />
          <Card title="Active chains" val={formatNumber(r.active_chains)} ok />
          <Card title="Paused chains" val={formatNumber(r.paused_chains)} sub="watchlist" />
          <Card title="Offboarded chains" val={formatNumber(r.offboarded_chains)} danger={r.offboarded_chains > 0} />
          <Card title="Total member hospitals" val={formatNumber(r.total_member_hospitals)} sub="across all chains" />
          <Card title="Avg members per chain" val={Number(r.avg_members_per_chain).toFixed(2)} />
          <Card title="Members with active AMC" val={formatNumber(r.members_with_active_amc)} ok />
          <Card title="AMC coverage %" val={`${Number(r.amc_coverage_pct).toFixed(1)}%`} ok={r.amc_coverage_pct >= 60} danger={r.amc_coverage_pct < 30} />
          <Card title="Pending invites" val={formatNumber(r.pending_invites)} sub="not-yet-accepted" />
          <Card title="New chains 30d" val={formatNumber(r.new_chains_30d)} />
          <Card title="New chains today" val={formatNumber(r.new_chains_today)} />
          <Card title="Chain revenue 90d (INR)" val={formatNumber(r.chain_revenue_90d_rupees)} sub="AMC paid + repair-job gross" />
          <Card title="Chains with zero AMC coverage" val={formatNumber(r.chains_zero_amc_coverage)} danger={r.chains_zero_amc_coverage > 0} sub="upsell target" />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}