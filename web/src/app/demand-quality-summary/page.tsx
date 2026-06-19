import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Demand quality summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_hospitals: number;
  amc_coverage_pct: number;
  active_30d_pct: number;
  active_90d_pct: number;
  loyalty_10_plus_pct: number;
  never_posted_pct: number;
  churn_signal_pct: number;
  avg_spend_per_active_30d_inr: number;
  cancellation_rate_pct_30d: number;
  disputes_filed_by_hosp_30d: number;
  repeat_buyer_pct: number;
  composite_demand_score: number;
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
const inr = (n: number) => `₹${Number(n).toLocaleString("en-IN")}`;

export default async function DemandQualitySummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_demand_quality_summary");
  if (error) throw new Error(`founder_demand_quality_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Demand quality summary</h1>
        <span className="text-xs text-[var(--color-muted)]">Composite hospital-trust score · AMC coverage + activity + loyalty + churn</span>
      </header>
      {r ? (
        <>
          <div className={`rounded-lg border-2 p-6 ${r.composite_demand_score >= 60 ? "border-[var(--color-ok)]" : r.composite_demand_score >= 40 ? "border-[var(--color-warn)]" : "border-[var(--color-danger)]"} bg-[var(--color-surface)]`}>
            <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">Composite demand quality score</div>
            <div className="mt-2 text-4xl font-bold tabular-nums">{pct(r.composite_demand_score)}</div>
            <div className="mt-1 text-xs text-[var(--color-muted)]">avg of 7 signals · AMC + active + loyalty + repeat + (100-never) + (100-churn) + (100-cancel)</div>
          </div>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
            <Card title="Total hospitals" val={formatNumber(r.total_hospitals)} />
            <Card title="AMC coverage" val={pct(r.amc_coverage_pct)} ok={r.amc_coverage_pct >= 30} />
            <Card title="Active 30d" val={pct(r.active_30d_pct)} ok={r.active_30d_pct >= 40} />
            <Card title="Active 90d" val={pct(r.active_90d_pct)} />
            <Card title="Loyalty (10+ jobs)" val={pct(r.loyalty_10_plus_pct)} ok />
            <Card title="Repeat buyer" val={pct(r.repeat_buyer_pct)} sub="≥2 lifetime jobs" />
            <Card title="Never posted" val={pct(r.never_posted_pct)} danger={r.never_posted_pct > 50} sub="onboarding gap" />
            <Card title="Churn signal" val={pct(r.churn_signal_pct)} danger={r.churn_signal_pct > 30} sub="60-90d active, then silent" />
            <Card title="Cancellation rate 30d" val={pct(r.cancellation_rate_pct_30d)} danger={r.cancellation_rate_pct_30d > 10} />
            <Card title="Avg spend / active 30d" val={inr(r.avg_spend_per_active_30d_inr)} />
            <Card title="Disputes by hosp 30d" val={formatNumber(r.disputes_filed_by_hosp_30d)} danger={r.disputes_filed_by_hosp_30d > 0} />
          </div>
        </>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
