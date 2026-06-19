import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Hospitals snapshot summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_all_time: number;
  with_active_amc: number;
  without_amc: number;
  amc_coverage_pct: number;
  active_30d: number;
  active_7d: number;
  jobs_posted_30d: number;
  spend_30d_inr: number;
  avg_spend_per_active: number;
  loyalty_10_plus: number;
  never_posted_a_job: number;
  new_signups_30d: number;
  new_signups_today: number;
  posted_today: number;
  distinct_cities_30d: number;
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

export default async function HospitalsSnapshotSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_hospitals_snapshot_summary");
  if (error) throw new Error(`founder_hospitals_snapshot_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Hospitals snapshot summary</h1>
        <span className="text-xs text-[var(--color-muted)]">15-KPI demand dashboard · AMC coverage + activity + loyalty · pair with /hospitals-index</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Total hospitals all-time" val={formatNumber(r.total_all_time)} />
          <Card title="With active AMC" val={formatNumber(r.with_active_amc)} ok sub={`${Number(r.amc_coverage_pct).toFixed(1)}% coverage`} />
          <Card title="Without AMC" val={formatNumber(r.without_amc)} sub="upsell pool" />
          <Card title="Active 30d" val={formatNumber(r.active_30d)} sub="posted ≥1 job" />
          <Card title="Active 7d" val={formatNumber(r.active_7d)} />
          <Card title="Jobs posted 30d" val={formatNumber(r.jobs_posted_30d)} />
          <Card title="Spend 30d" val={inr(r.spend_30d_inr)} ok sub="contracted_amount on completed" />
          <Card title="Avg spend / active" val={inr(r.avg_spend_per_active)} sub="30d completed" />
          <Card title="Loyalty (10+ jobs)" val={formatNumber(r.loyalty_10_plus)} ok sub="lifetime power-users" />
          <Card title="Never posted a job" val={formatNumber(r.never_posted_a_job)} sub="onboarding gap" />
          <Card title="New signups 30d" val={formatNumber(r.new_signups_30d)} />
          <Card title="New signups today" val={formatNumber(r.new_signups_today)} />
          <Card title="Posted today" val={formatNumber(r.posted_today)} />
          <Card title="Active cities 30d" val={formatNumber(r.distinct_cities_30d)} sub="geographic reach" />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
