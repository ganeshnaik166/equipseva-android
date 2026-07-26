import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { milestone_status: string; projects: number; pct: number };
type ScoreRow = {
  milestone: string;
  projects: number;
  completed: number;
  on_track: number;
  delayed: number;
  blocked: number;
  avg_planned_days: number;
  avg_actual_days: number;
  avg_variance_days: number;
};
type MatrixRow = {
  milestone: string;
  bottleneck: string;
  projects: number;
  delayed: number;
  avg_variance_days: number;
};
type TrendRow = {
  cycle_month: string;
  projects: number;
  avg_planned_days: number;
  avg_actual_days: number;
  avg_variance_days: number;
  delayed: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_added_delay_days: number;
  avg_cost_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_added_delay_days: number;
  pct: number;
};
type ImpactRow = {
  delay_impact: string;
  findings: number;
  open_findings: number;
  total_added_delay_days: number;
  total_cost_rupees: number;
};
type RiskRow = {
  engineer_name: string;
  hospital_name: string;
  project_code: string;
  device_model: string;
  milestone: string;
  milestone_status: string;
  bottleneck: string;
  planned_days: number | null;
  actual_days: number | null;
  variance_days: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    scoreRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3460_milestone_status_rollup'),
    supabase.rpc('founder_r3460_milestone_scorecard'),
    supabase.rpc('founder_r3460_milestone_bottleneck_matrix'),
    supabase.rpc('founder_r3460_monthly_cycle_time_trend'),
    supabase.rpc('founder_r3460_capa_status_board'),
    supabase.rpc('founder_r3460_root_cause_pareto'),
    supabase.rpc('founder_r3460_lead_time_impact_digest'),
    supabase.rpc('founder_r3460_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const scoreRows: ScoreRow[] = (scoreRes.data as ScoreRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'milestone_status', header: 'Milestone Status' },
    { key: 'projects', header: 'Projects' },
    { key: 'pct', header: 'Share %' },
  ];

  const scoreCols: Column<ScoreRow>[] = [
    { key: 'milestone', header: 'Milestone' },
    { key: 'projects', header: 'Projects' },
    { key: 'completed', header: 'Completed' },
    { key: 'on_track', header: 'On Track' },
    { key: 'delayed', header: 'Delayed' },
    { key: 'blocked', header: 'Blocked' },
    { key: 'avg_planned_days', header: 'Avg Planned Days' },
    { key: 'avg_actual_days', header: 'Avg Actual Days' },
    { key: 'avg_variance_days', header: 'Avg Variance Days' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'milestone', header: 'Milestone' },
    { key: 'bottleneck', header: 'Bottleneck' },
    { key: 'projects', header: 'Projects' },
    { key: 'delayed', header: 'Delayed / Blocked' },
    { key: 'avg_variance_days', header: 'Avg Variance Days' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'cycle_month', header: 'Month' },
    { key: 'projects', header: 'Projects' },
    { key: 'avg_planned_days', header: 'Avg Planned Days' },
    { key: 'avg_actual_days', header: 'Avg Actual Days' },
    { key: 'avg_variance_days', header: 'Avg Variance Days' },
    { key: 'delayed', header: 'Delayed / Blocked' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_added_delay_days', header: 'Avg Added Delay Days' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_added_delay_days', header: 'Total Added Delay Days' },
    { key: 'pct', header: 'Share %' },
  ];

  const impactCols: Column<ImpactRow>[] = [
    { key: 'delay_impact', header: 'Lead-Time Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_added_delay_days', header: 'Total Added Delay Days' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'project_code', header: 'Project' },
    { key: 'device_model', header: 'Device' },
    { key: 'milestone', header: 'Milestone' },
    { key: 'milestone_status', header: 'Status' },
    { key: 'bottleneck', header: 'Bottleneck' },
    { key: 'planned_days', header: 'Planned Days' },
    { key: 'actual_days', header: 'Actual Days' },
    { key: 'variance_days', header: 'Variance Days' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Installation Lead-Time / Cycle-Time Milestone Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Installation delivery ops from PO to go-live — project &times; milestone (PO received, site
        survey, dispatch, delivery, installation, commissioning, handover, go-live) &times; planned
        vs. actual vs. variance days &times; milestone status &times; bottleneck (site readiness,
        logistics, customs, manpower, parts, customer sign-off) &amp; CAPA schedule-recovery closure.
        Founder-gated view: milestone status rollups, milestone scorecards, cycle-time trend,
        root-cause pareto, and lead-time impact digest across the install portfolio.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Milestone status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No milestone records logged yet."
          rowKey={(r, i) => String(r.milestone_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Milestone scorecard</h2>
        <DataTable
          rows={scoreRows}
          columns={scoreCols}
          emptyMessage="No milestone rollups."
          rowKey={(r, i) => String(r.milestone ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Milestone &times; bottleneck matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No records by milestone."
          rowKey={(r, i) => `${r.milestone}-${r.bottleneck}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly cycle-time trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.cycle_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Lead-time impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No lead-time impact rollups."
          rowKey={(r, i) => String(r.delay_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk milestone queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk milestones."
          rowKey={(r, i) => `${r.project_code}-${r.milestone}-${i}`}
        />
      </section>
    </main>
  );
}
