import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Cumulative roll-up snapshot summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  days_since_launch: number;
  lifetime_jobs_completed: number;
  lifetime_jobs_gmv_inr: number;
  lifetime_amc_revenue_inr: number;
  lifetime_parts_revenue_inr: number;
  lifetime_gmv_total_inr: number;
  lifetime_payouts_disbursed_inr: number;
  lifetime_referral_bounties_inr: number;
  lifetime_engineers_onboarded: number;
  lifetime_hospitals_onboarded: number;
  lifetime_amc_contracts_created: number;
  lifetime_spare_part_orders: number;
  avg_gmv_per_day_inr: number;
  avg_jobs_per_day: number;
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

export default async function CumulativeRollupSummarySnapshotSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_cumulative_rollup_summary");
  if (error) throw new Error(`founder_cumulative_rollup_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Cumulative roll-up snapshot summary</h1>
        <span className="text-xs text-[var(--color-muted)]">14-KPI lifetime autobiography · all-time running totals · investor-deck row</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Days since launch" val={formatNumber(r.days_since_launch)} sub="from first signup" />
          <Card title="Lifetime jobs completed" val={formatNumber(r.lifetime_jobs_completed)} ok />
          <Card title="Lifetime jobs GMV" val={inr(r.lifetime_jobs_gmv_inr)} ok sub="contracted on completed" />
          <Card title="Lifetime AMC revenue" val={inr(r.lifetime_amc_revenue_inr)} ok sub="paid orders" />
          <Card title="Lifetime parts revenue" val={inr(r.lifetime_parts_revenue_inr)} ok sub="paid spare-part orders" />
          <Card title="Lifetime GMV total" val={inr(r.lifetime_gmv_total_inr)} ok sub="jobs + AMC + parts" />
          <Card title="Lifetime payouts disbursed" val={inr(r.lifetime_payouts_disbursed_inr)} sub="engineer earnings" />
          <Card title="Lifetime referral bounties" val={inr(r.lifetime_referral_bounties_inr)} sub="growth incentives paid" />
          <Card title="Engineers onboarded" val={formatNumber(r.lifetime_engineers_onboarded)} />
          <Card title="Hospitals onboarded" val={formatNumber(r.lifetime_hospitals_onboarded)} />
          <Card title="AMC contracts created" val={formatNumber(r.lifetime_amc_contracts_created)} />
          <Card title="Spare-part orders" val={formatNumber(r.lifetime_spare_part_orders)} />
          <Card title="Avg GMV / day" val={inr(r.avg_gmv_per_day_inr)} sub="lifetime / days" />
          <Card title="Avg jobs / day" val={Number(r.avg_jobs_per_day).toFixed(2)} sub="completion velocity" />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
