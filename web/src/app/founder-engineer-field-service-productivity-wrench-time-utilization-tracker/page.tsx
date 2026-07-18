import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { productivity_verdict: string; engineer_periods: number; pct: number };
type ScorecardRow = {
  engineer_name: string;
  region: string;
  periods: number;
  avg_wrench_time_pct: number;
  avg_travel_pct: number;
  avg_jobs_per_day: number;
  avg_first_time_fix_pct: number;
  avg_capacity_utilization_pct: number;
  total_overtime_hours: number;
  high_performer_periods: number;
};
type MatrixRow = {
  region: string;
  productivity_verdict: string;
  engineer_periods: number;
  avg_wrench_time_pct: number;
  avg_capacity_utilization_pct: number;
};
type TrendRow = {
  period_week: string;
  engineer_periods: number;
  avg_wrench_time_pct: number;
  avg_jobs_per_day: number;
  overloaded: number;
  underutilized: number;
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
  business_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  engineer_name: string;
  region: string;
  period_week: string;
  productivity_verdict: string;
  wrench_time_pct: number;
  travel_pct: number;
  jobs_per_day: number;
  first_time_fix_pct: number;
  capacity_utilization_pct: number;
  overtime_hours: number;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    scorecardRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3316_verdict_rollup'),
    supabase.rpc('founder_r3316_engineer_scorecard'),
    supabase.rpc('founder_r3316_region_verdict_matrix'),
    supabase.rpc('founder_r3316_weekly_trend'),
    supabase.rpc('founder_r3316_capa_status_board'),
    supabase.rpc('founder_r3316_root_cause_pareto'),
    supabase.rpc('founder_r3316_business_impact_digest'),
    supabase.rpc('founder_r3316_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const scorecardRows: ScorecardRow[] = (scorecardRes.data as ScorecardRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'productivity_verdict', header: 'Verdict' },
    { key: 'engineer_periods', header: 'Engineer-Periods' },
    { key: 'pct', header: 'Share %' },
  ];

  const scorecardCols: Column<ScorecardRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'region', header: 'Region' },
    { key: 'periods', header: 'Periods' },
    { key: 'avg_wrench_time_pct', header: 'Avg Wrench-Time %' },
    { key: 'avg_travel_pct', header: 'Avg Travel %' },
    { key: 'avg_jobs_per_day', header: 'Avg Jobs/Day' },
    { key: 'avg_first_time_fix_pct', header: 'Avg FTF %' },
    { key: 'avg_capacity_utilization_pct', header: 'Avg Capacity %' },
    { key: 'total_overtime_hours', header: 'Total OT (h)' },
    { key: 'high_performer_periods', header: 'High-Perf Periods' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'region', header: 'Region' },
    { key: 'productivity_verdict', header: 'Verdict' },
    { key: 'engineer_periods', header: 'Engineer-Periods' },
    { key: 'avg_wrench_time_pct', header: 'Avg Wrench-Time %' },
    { key: 'avg_capacity_utilization_pct', header: 'Avg Capacity %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_week', header: 'Week' },
    { key: 'engineer_periods', header: 'Engineer-Periods' },
    { key: 'avg_wrench_time_pct', header: 'Avg Wrench-Time %' },
    { key: 'avg_jobs_per_day', header: 'Avg Jobs/Day' },
    { key: 'overloaded', header: 'Overloaded' },
    { key: 'underutilized', header: 'Underutilized' },
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
    { key: 'business_impact', header: 'Business Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'region', header: 'Region' },
    { key: 'period_week', header: 'Week' },
    { key: 'productivity_verdict', header: 'Verdict' },
    { key: 'wrench_time_pct', header: 'Wrench-Time %' },
    { key: 'travel_pct', header: 'Travel %' },
    { key: 'jobs_per_day', header: 'Jobs/Day' },
    { key: 'first_time_fix_pct', header: 'FTF %' },
    { key: 'capacity_utilization_pct', header: 'Capacity %' },
    { key: 'overtime_hours', header: 'OT (h)' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Field-Service Productivity &mdash; Wrench-Time &amp; Utilization Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Per engineer-period field-service productivity &mdash; region &times; productivity verdict
        &times; wrench-time % (hands-on-tool vs total shift) &times; travel % &times; jobs-per-day
        &times; first-time-fix % &times; capacity utilization &times; overtime &amp; routing /
        scheduling / coaching CAPA. Founder-gated view: verdict rollups, engineer scorecards,
        root-cause pareto, and business-impact digest for productivity coaching and territory
        rebalancing.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Productivity verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No engineer-periods logged yet."
          rowKey={(r, i) => String(r.productivity_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Engineer productivity scorecard</h2>
        <DataTable
          rows={scorecardRows}
          columns={scorecardCols}
          emptyMessage="No engineer rollups."
          rowKey={(r, i) => `${r.engineer_name}-${r.region}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Region &times; verdict matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No periods by region."
          rowKey={(r, i) => `${r.region}-${r.productivity_verdict}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Weekly productivity trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.period_week ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Business-impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No business-impact rollups."
          rowKey={(r, i) => String(r.business_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk productivity queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk engineer-periods."
          rowKey={(r, i) => `${r.engineer_name}-${r.period_week}-${i}`}
        />
      </section>
    </main>
  );
}
