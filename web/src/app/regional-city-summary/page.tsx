import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Regional city summary snapshot — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  distinct_cities_30d: number;
  top1_city: string;
  top1_jobs_30d: number;
  top1_revenue_rupees_30d: number;
  top1_active_amcs: number;
  top1_engineers_30d: number;
  top1_hospitals_30d: number;
  top2_city: string;
  top2_jobs_30d: number;
  top3_city: string;
  top3_jobs_30d: number;
  top1_share_jobs_pct: number;
  total_jobs_30d: number;
  total_revenue_rupees_30d: number;
  unknown_city_jobs_30d: number;
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

export default async function RegionalCitySummarySnapshotSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_regional_city_summary");
  if (error) throw new Error(`founder_regional_city_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Regional city summary snapshot</h1>
        <span className="text-xs text-[var(--color-muted)]">15-KPI city-grain rollup &middot; top-3 cities by composite activity 30d &middot; pair with /amc-by-city /amc-revenue-by-city /signups-by-city /demand-by-city /jobs-revenue-by-city /tier-distribution-by-city /hospital-amc-coverage-by-city /engineers-by-tier-by-city /amc-pool-balance-by-city /city-coverage</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Active cities 30d" val={formatNumber(r.distinct_cities_30d)} sub="urban footprint" />
          <Card title="#1 city" val={r.top1_city} ok sub="composite-activity leader" />
          <Card title="#1 jobs 30d" val={formatNumber(r.top1_jobs_30d)} ok />
          <Card title="#1 revenue 30d" val={inr(r.top1_revenue_rupees_30d)} ok sub="contracted on completed" />
          <Card title="#1 active AMCs" val={formatNumber(r.top1_active_amcs)} />
          <Card title="#1 engineers 30d" val={formatNumber(r.top1_engineers_30d)} sub="touched a job" />
          <Card title="#1 hospitals 30d" val={formatNumber(r.top1_hospitals_30d)} sub="posted a job" />
          <Card title="#2 city" val={r.top2_city} sub={`${formatNumber(r.top2_jobs_30d)} jobs 30d`} />
          <Card title="#3 city" val={r.top3_city} sub={`${formatNumber(r.top3_jobs_30d)} jobs 30d`} />
          <Card title="#1 share of jobs" val={`${Number(r.top1_share_jobs_pct).toFixed(1)}%`} sub="city concentration risk if >50%" danger={Number(r.top1_share_jobs_pct) > 50} />
          <Card title="Total jobs 30d" val={formatNumber(r.total_jobs_30d)} />
          <Card title="Total revenue 30d" val={inr(r.total_revenue_rupees_30d)} ok />
          <Card title="Unknown-city jobs 30d" val={formatNumber(r.unknown_city_jobs_30d)} danger={r.unknown_city_jobs_30d > 0} sub="profile.city empty &mdash; data hygiene gap" />
          <Card title="#2 jobs 30d" val={formatNumber(r.top2_jobs_30d)} />
          <Card title="#3 jobs 30d" val={formatNumber(r.top3_jobs_30d)} />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
