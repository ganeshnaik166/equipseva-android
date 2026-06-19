import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Risk score snapshots summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_snapshots: number;
  distinct_actors_scored: number;
  engineer_snapshots: number;
  hospital_snapshots: number;
  admin_snapshots: number;
  founder_snapshots: number;
  latest_clean_actors: number;
  latest_watch_actors: number;
  latest_high_actors: number;
  latest_critical_actors: number;
  avg_latest_score: number;
  median_latest_score: number;
  max_latest_score: number;
  min_latest_score: number;
  alert_only_count: number;
  founder_reviewed_count: number;
  blocked_count: number;
  cleared_count: number;
  snapshots_today_ist: number;
  snapshots_last_7d: number;
  snapshots_last_30d: number;
  newest_computed_at: string | null;
  oldest_computed_at: string | null;
  hours_since_last_snapshot: number | null;
  high_or_critical_share_pct: number;
  engineers_in_critical_band: number;
  hospitals_in_critical_band: number;
  band_transitions_7d: number;
  worsened_actors_7d: number;
  improved_actors_7d: number;
  avg_disputed_jobs_signal: number;
  avg_overdue_renewals_signal: number;
  avg_suspicious_distance_signal: number;
  top_score_email: string | null;
  top_score_value: number | null;
  top_score_band: string | null;
  top_score_role: string | null;
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

export default async function RiskScoreSnapshotsSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_risk_score_snapshots_summary");
  if (error) throw new Error(`founder_risk_score_snapshots_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Risk score snapshots summary</h1>
        <span className="text-xs text-[var(--color-muted)]">Forensic risk telemetry · band distribution + action funnel + drift · alert-only mode</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Total snapshots" val={formatNumber(r.total_snapshots)} />
          <Card title="Distinct actors scored" val={formatNumber(r.distinct_actors_scored)} />
          <Card title="Latest: clean" val={formatNumber(r.latest_clean_actors)} ok sub="band &lt; 20" />
          <Card title="Latest: watch" val={formatNumber(r.latest_watch_actors)} sub="band 20-39" />
          <Card title="Latest: high" val={formatNumber(r.latest_high_actors)} sub="band 40-69" />
          <Card title="Latest: critical" val={formatNumber(r.latest_critical_actors)} danger={r.latest_critical_actors > 0} sub="band &ge; 70" />
          <Card title="High or critical %" val={`${Number(r.high_or_critical_share_pct).toFixed(1)}%`} danger={r.high_or_critical_share_pct > 5} />
          <Card title="Avg latest score" val={Number(r.avg_latest_score).toFixed(1)} sub="0-100 scale" />
          <Card title="Engineers critical" val={formatNumber(r.engineers_in_critical_band)} danger={r.engineers_in_critical_band > 0} />
          <Card title="Hospitals critical" val={formatNumber(r.hospitals_in_critical_band)} danger={r.hospitals_in_critical_band > 0} />
          <Card title="Snapshots today" val={formatNumber(r.snapshots_today_ist)} />
          <Card title="Snapshots 7d" val={formatNumber(r.snapshots_last_7d)} />
          <Card title="Action: alert_only" val={formatNumber(r.alert_only_count)} sub="lifetime" />
          <Card title="Action: founder reviewed" val={formatNumber(r.founder_reviewed_count)} ok />
          <Card title="Action: blocked" val={formatNumber(r.blocked_count)} danger={r.blocked_count > 0} />
          <Card title="Action: cleared" val={formatNumber(r.cleared_count)} ok />
          <Card title="Worsened 7d" val={formatNumber(r.worsened_actors_7d)} danger={r.worsened_actors_7d > 0} />
          <Card title="Improved 7d" val={formatNumber(r.improved_actors_7d)} ok />
          <Card title="Band transitions 7d" val={formatNumber(r.band_transitions_7d)} />
          <Card title="Top scorer band" val={(r.top_score_band ?? "—") + " · " + (r.top_score_value ?? 0)} danger={r.top_score_band === "critical"} sub={r.top_score_email ?? "—"} />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No risk snapshots yet. Cron runs 03:00 IST.</p>}
    </div>
  );
}
