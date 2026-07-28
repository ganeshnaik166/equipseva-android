import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { load_status: string; weeks: number; pct: number };
type RegionRow = {
  region: string;
  total_weeks: number;
  total_pm_due: number;
  total_pm_completed: number;
  total_carryover: number;
  over_loaded_weeks: number;
  critical_weeks: number;
  avg_utilization_pct: number;
  completion_pct: number;
};
type MatrixRow = {
  region: string;
  load_status: string;
  weeks: number;
  total_carryover: number;
  avg_utilization_pct: number;
};
type TrendRow = {
  month: string;
  weeks: number;
  total_pm_due: number;
  total_pm_completed: number;
  total_carryover: number;
  avg_utilization_pct: number;
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
  sla_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  engineer_name: string;
  region: string;
  schedule_ref: string;
  schedule_week: string;
  load_status: string;
  pm_due: number;
  pm_completed: number;
  carryover: number;
  utilization_pct: number;
  balancing_action: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    regionRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3540_load_status_rollup'),
    supabase.rpc('founder_r3540_region_scorecard'),
    supabase.rpc('founder_r3540_region_load_status_matrix'),
    supabase.rpc('founder_r3540_monthly_workload_trend'),
    supabase.rpc('founder_r3540_capa_status_board'),
    supabase.rpc('founder_r3540_root_cause_pareto'),
    supabase.rpc('founder_r3540_backlog_impact_digest'),
    supabase.rpc('founder_r3540_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const regionRows: RegionRow[] = (regionRes.data as RegionRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'load_status', header: 'Load Status' },
    { key: 'weeks', header: 'Weeks' },
    { key: 'pct', header: 'Share %' },
  ];

  const regionCols: Column<RegionRow>[] = [
    { key: 'region', header: 'Region' },
    { key: 'total_weeks', header: 'Weeks' },
    { key: 'total_pm_due', header: 'PM Due' },
    { key: 'total_pm_completed', header: 'PM Completed' },
    { key: 'total_carryover', header: 'Carryover' },
    { key: 'over_loaded_weeks', header: 'Over-loaded' },
    { key: 'critical_weeks', header: 'Critical' },
    { key: 'avg_utilization_pct', header: 'Avg Util %' },
    { key: 'completion_pct', header: 'Completion %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'region', header: 'Region' },
    { key: 'load_status', header: 'Load Status' },
    { key: 'weeks', header: 'Weeks' },
    { key: 'total_carryover', header: 'Carryover' },
    { key: 'avg_utilization_pct', header: 'Avg Util %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'month', header: 'Month' },
    { key: 'weeks', header: 'Weeks' },
    { key: 'total_pm_due', header: 'PM Due' },
    { key: 'total_pm_completed', header: 'PM Completed' },
    { key: 'total_carryover', header: 'Carryover' },
    { key: 'avg_utilization_pct', header: 'Avg Util %' },
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
    { key: 'sla_impact', header: 'SLA Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'region', header: 'Region' },
    { key: 'schedule_ref', header: 'Schedule Ref' },
    { key: 'schedule_week', header: 'Week' },
    { key: 'load_status', header: 'Load Status' },
    { key: 'pm_due', header: 'PM Due' },
    { key: 'pm_completed', header: 'PM Done' },
    { key: 'carryover', header: 'Carryover' },
    { key: 'utilization_pct', header: 'Util %' },
    { key: 'balancing_action', header: 'Action' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer PM-Scheduling / Workload Load-Balancing Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Per-engineer per-week preventive-maintenance scheduling &amp; workload load-balancing across
        regions &mdash; PM due &times; scheduled &times; completed &times; capacity vs scheduled hours
        &times; utilization &times; load status (under-loaded &rarr; critical overload) &times; carryover
        &times; reschedule count &times; balancing action (reassign, defer, overtime, contractor,
        escalate) &amp; CAPA closure. Founder-gated view: load-status mix, region scorecards, root-cause
        pareto, and backlog / SLA-impact digest across the field-service network.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Load-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No weekly workload rows logged yet."
          rowKey={(r, i) => String(r.load_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Region workload scorecard</h2>
        <DataTable
          rows={regionRows}
          columns={regionCols}
          emptyMessage="No region rollups."
          rowKey={(r, i) => String(r.region ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Region &times; load-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No matrix data."
          rowKey={(r, i) => `${r.region}-${r.load_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly workload trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Backlog / SLA-impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No SLA-impact rollups."
          rowKey={(r, i) => String(r.sla_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk workload queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk workload rows."
          rowKey={(r, i) => `${r.schedule_ref}-${r.schedule_week}-${i}`}
        />
      </section>
    </main>
  );
}
