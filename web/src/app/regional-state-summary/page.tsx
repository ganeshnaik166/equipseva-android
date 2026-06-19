import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Regional state summary snapshot — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  distinct_states_30d: number;
  top1_state: string;
  top1_jobs_30d: number;
  top1_revenue_rupees_30d: number;
  top1_active_amcs: number;
  top1_engineers_30d: number;
  top1_hospitals_30d: number;
  top2_state: string;
  top2_jobs_30d: number;
  top3_state: string;
  top3_jobs_30d: number;
  top1_share_jobs_pct: number;
  total_jobs_30d: number;
  total_revenue_rupees_30d: number;
  unknown_state_jobs_30d: number;
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

export default async function RegionalStateSummarySnapshotSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_regional_state_summary");
  if (error) throw new Error(`founder_regional_state_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Regional state summary snapshot</h1>
        <span className="text-xs text-[var(--color-muted)]">15-KPI regional rollup &middot; top-3 states by composite activity 30d &middot; pair with /amc-by-state /jobs-by-state /payouts-by-state /spare-parts-by-state</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Active states 30d" val={formatNumber(r.distinct_states_30d)} sub="geographic reach" />
          <Card title="#1 state" val={r.top1_state} ok sub="composite-activity leader" />
          <Card title="#1 jobs 30d" val={formatNumber(r.top1_jobs_30d)} ok />
          <Card title="#1 revenue 30d" val={inr(r.top1_revenue_rupees_30d)} ok sub="contracted on completed" />
          <Card title="#1 active AMCs" val={formatNumber(r.top1_active_amcs)} />
          <Card title="#1 engineers 30d" val={formatNumber(r.top1_engineers_30d)} sub="touched a job" />
          <Card title="#1 hospitals 30d" val={formatNumber(r.top1_hospitals_30d)} sub="posted a job" />
          <Card title="#2 state" val={r.top2_state} sub={`${formatNumber(r.top2_jobs_30d)} jobs 30d`} />
          <Card title="#3 state" val={r.top3_state} sub={`${formatNumber(r.top3_jobs_30d)} jobs 30d`} />
          <Card title="#1 share of jobs" val={`${Number(r.top1_share_jobs_pct).toFixed(1)}%`} sub="concentration risk if >50%" danger={Number(r.top1_share_jobs_pct) > 50} />
          <Card title="Total jobs 30d" val={formatNumber(r.total_jobs_30d)} />
          <Card title="Total revenue 30d" val={inr(r.total_revenue_rupees_30d)} ok />
          <Card title="Unknown-state jobs 30d" val={formatNumber(r.unknown_state_jobs_30d)} danger={r.unknown_state_jobs_30d > 0} sub="profile.state empty &mdash; data hygiene gap" />
          <Card title="#2 jobs 30d" val={formatNumber(r.top2_jobs_30d)} />
          <Card title="#3 jobs 30d" val={formatNumber(r.top3_jobs_30d)} />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
