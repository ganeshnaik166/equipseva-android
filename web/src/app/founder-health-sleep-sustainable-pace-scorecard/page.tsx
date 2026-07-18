import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { burnout_risk_verdict: string; weeks: number; pct: number };
type SiteRow = {
  anchor_hospital_site: string;
  weeks: number;
  avg_sleep_hours: number;
  avg_screen_time_hours: number;
  total_workouts: number;
  recovery_weeks: number;
  at_risk_weeks: number;
  sustainable_pct: number;
};
type MatrixRow = {
  stress_rating: string;
  energy_trend: string;
  weeks: number;
  avg_sleep_hours: number;
  avg_deep_work_blocks: number;
};
type TrendRow = {
  week_start_date: string;
  week_label: string;
  avg_sleep_hours: number;
  workout_sessions: number;
  avg_screen_time_hours: number;
  deep_work_blocks: number;
  recovery_day_taken: boolean;
  burnout_risk_verdict: string;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cost_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_rupees: number;
  pct: number;
};
type ImpactRow = {
  regulatory_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  week_label: string;
  week_start_date: string;
  anchor_hospital_site: string;
  avg_sleep_hours: number;
  stress_rating: string;
  energy_trend: string;
  burnout_risk_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    siteRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3229_burnout_verdict_rollup'),
    supabase.rpc('founder_r3229_site_scorecard'),
    supabase.rpc('founder_r3229_stress_energy_matrix'),
    supabase.rpc('founder_r3229_weekly_pace_trend'),
    supabase.rpc('founder_r3229_capa_status_board'),
    supabase.rpc('founder_r3229_root_cause_pareto'),
    supabase.rpc('founder_r3229_impact_digest'),
    supabase.rpc('founder_r3229_high_risk_weeks_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const siteRows: SiteRow[] = (siteRes.data as SiteRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'burnout_risk_verdict', header: 'Burnout Verdict' },
    { key: 'weeks', header: 'Weeks' },
    { key: 'pct', header: 'Share %' },
  ];

  const siteCols: Column<SiteRow>[] = [
    { key: 'anchor_hospital_site', header: 'Anchor Site' },
    { key: 'weeks', header: 'Weeks' },
    { key: 'avg_sleep_hours', header: 'Avg Sleep (hrs)' },
    { key: 'avg_screen_time_hours', header: 'Avg Screen (hrs)' },
    { key: 'total_workouts', header: 'Workouts' },
    { key: 'recovery_weeks', header: 'Recovery Wks' },
    { key: 'at_risk_weeks', header: 'At-Risk Wks' },
    { key: 'sustainable_pct', header: 'Sustainable %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'stress_rating', header: 'Stress' },
    { key: 'energy_trend', header: 'Energy Trend' },
    { key: 'weeks', header: 'Weeks' },
    { key: 'avg_sleep_hours', header: 'Avg Sleep (hrs)' },
    { key: 'avg_deep_work_blocks', header: 'Avg Deep-Work Blocks' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'week_start_date', header: 'Week Start' },
    { key: 'week_label', header: 'Week' },
    { key: 'avg_sleep_hours', header: 'Sleep (hrs)' },
    { key: 'workout_sessions', header: 'Workouts' },
    { key: 'avg_screen_time_hours', header: 'Screen (hrs)' },
    { key: 'deep_work_blocks', header: 'Deep-Work Blocks' },
    { key: 'recovery_day_taken', header: 'Recovery Day' },
    { key: 'burnout_risk_verdict', header: 'Verdict' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const impactCols: Column<ImpactRow>[] = [
    { key: 'regulatory_impact', header: 'Visibility / Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'week_label', header: 'Week' },
    { key: 'week_start_date', header: 'Week Start' },
    { key: 'anchor_hospital_site', header: 'Anchor Site' },
    { key: 'avg_sleep_hours', header: 'Sleep (hrs)' },
    { key: 'stress_rating', header: 'Stress' },
    { key: 'energy_trend', header: 'Energy' },
    { key: 'burnout_risk_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Founder-Health, Sleep &amp; Sustainable-Pace Scorecard
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Weekly founder health log &mdash; sleep &times; workouts &times; screen-time &times;
        deep-work blocks &times; stress &times; recovery days &times; energy trend &amp;
        burnout-risk verdict, with rebalance CAPA actions. Founder-gated view: verdict rollup,
        anchor-site scorecards, stress&ndash;energy matrix, root-cause pareto, and impact digest.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Burnout-risk verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No health weeks logged yet."
          rowKey={(r, i) => String(r.burnout_risk_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Anchor-site scorecard</h2>
        <DataTable
          rows={siteRows}
          columns={siteCols}
          emptyMessage="No site rollups."
          rowKey={(r, i) => String(r.anchor_hospital_site ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Stress &times; energy trend matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No stress-energy data."
          rowKey={(r, i) => `${r.stress_rating}-${r.energy_trend}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Weekly pace trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.week_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA status board</h2>
        <DataTable
          rows={capaRows}
          columns={capaCols}
          emptyMessage="No CAPA findings."
          rowKey={(r, i) => String(r.capa_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Visibility &amp; impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk weeks queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk weeks."
          rowKey={(r, i) => `${r.week_label}-${r.week_start_date}-${i}`}
        />
      </section>
    </main>
  );
}
