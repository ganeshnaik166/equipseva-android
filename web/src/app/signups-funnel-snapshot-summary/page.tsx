import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Signups funnel snapshot summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_all_time: number;
  signups_today: number;
  signups_7d: number;
  signups_30d: number;
  engineer_signups_30d: number;
  hospital_signups_30d: number;
  engineers_with_bid_in_7d_30d: number;
  hospitals_with_job_in_7d_30d: number;
  engineer_first_action_pct: number;
  hospital_first_action_pct: number;
  signups_with_city_30d: number;
  stuck_no_action_over_14d: number;
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

export default async function SignupsFunnelSnapshotSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_signups_funnel_snapshot_summary");
  if (error) throw new Error(`founder_signups_funnel_snapshot_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Signups funnel snapshot summary</h1>
        <span className="text-xs text-[var(--color-muted)]">13-KPI top-of-funnel pulse · today/7d/30d by role + first-action % · pair with /signups-by-day</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Total signups all-time" val={formatNumber(r.total_all_time)} />
          <Card title="Signups today" val={formatNumber(r.signups_today)} ok={r.signups_today > 0} />
          <Card title="Signups 7d" val={formatNumber(r.signups_7d)} />
          <Card title="Signups 30d" val={formatNumber(r.signups_30d)} />
          <Card title="Engineer signups 30d" val={formatNumber(r.engineer_signups_30d)} />
          <Card title="Hospital signups 30d" val={formatNumber(r.hospital_signups_30d)} />
          <Card title="Engineers w/ bid <=7d (30d)" val={formatNumber(r.engineers_with_bid_in_7d_30d)} sub="first-action" />
          <Card title="Hospitals w/ job <=7d (30d)" val={formatNumber(r.hospitals_with_job_in_7d_30d)} sub="first-action" />
          <Card title="Engineer first-action %" val={`${Number(r.engineer_first_action_pct).toFixed(1)}%`} ok={Number(r.engineer_first_action_pct) >= 40} danger={Number(r.engineer_first_action_pct) < 20} />
          <Card title="Hospital first-action %" val={`${Number(r.hospital_first_action_pct).toFixed(1)}%`} ok={Number(r.hospital_first_action_pct) >= 40} danger={Number(r.hospital_first_action_pct) < 20} />
          <Card title="Signups w/ city 30d" val={formatNumber(r.signups_with_city_30d)} sub="geography captured" />
          <Card title="Stuck >14d no action" val={formatNumber(r.stuck_no_action_over_14d)} danger={r.stuck_no_action_over_14d > 0} sub="signup-only, 14-60d window" />
          <Card title="Distinct cities 30d" val={formatNumber(r.distinct_cities_30d)} sub="geo reach" />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
