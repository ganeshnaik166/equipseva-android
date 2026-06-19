import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Onboarding velocity summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  eng_cohort_90d: number;
  eng_median_signup_to_verified_h: number;
  eng_p90_signup_to_verified_h: number;
  eng_median_signup_to_first_bid_h: number;
  eng_p90_signup_to_first_bid_h: number;
  eng_stalled_no_bid_over_7d: number;
  hosp_cohort_90d: number;
  hosp_median_signup_to_first_job_h: number;
  hosp_p90_signup_to_first_job_h: number;
  hosp_median_signup_to_first_amc_d: number;
  hosp_stalled_no_job_over_7d: number;
  avg_signups_per_day_30d: number;
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

export default async function OnboardingVelocitySummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_onboarding_velocity_summary");
  if (error) throw new Error(`founder_onboarding_velocity_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Onboarding velocity summary</h1>
        <span className="text-xs text-[var(--color-muted)]">12-KPI median/p90 latency view · 90d cohort · pair with /signups-funnel</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Engineer cohort 90d" val={formatNumber(r.eng_cohort_90d)} sub="signups" />
          <Card title="Eng median signup→verified (h)" val={Number(r.eng_median_signup_to_verified_h).toFixed(1)} />
          <Card title="Eng p90 signup→verified (h)" val={Number(r.eng_p90_signup_to_verified_h).toFixed(1)} sub="tail" />
          <Card title="Eng median signup→first bid (h)" val={Number(r.eng_median_signup_to_first_bid_h).toFixed(1)} />
          <Card title="Eng p90 signup→first bid (h)" val={Number(r.eng_p90_signup_to_first_bid_h).toFixed(1)} sub="tail" />
          <Card title="Eng stalled (no bid >7d)" val={formatNumber(r.eng_stalled_no_bid_over_7d)} danger={r.eng_stalled_no_bid_over_7d > 0} sub="activation gap" />
          <Card title="Hospital cohort 90d" val={formatNumber(r.hosp_cohort_90d)} sub="signups" />
          <Card title="Hosp median signup→first job (h)" val={Number(r.hosp_median_signup_to_first_job_h).toFixed(1)} />
          <Card title="Hosp p90 signup→first job (h)" val={Number(r.hosp_p90_signup_to_first_job_h).toFixed(1)} sub="tail" />
          <Card title="Hosp median signup→first AMC (d)" val={Number(r.hosp_median_signup_to_first_amc_d).toFixed(1)} ok />
          <Card title="Hosp stalled (no job >7d)" val={formatNumber(r.hosp_stalled_no_job_over_7d)} danger={r.hosp_stalled_no_job_over_7d > 0} sub="activation gap" />
          <Card title="Avg signups/day 30d" val={Number(r.avg_signups_per_day_30d).toFixed(1)} />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}