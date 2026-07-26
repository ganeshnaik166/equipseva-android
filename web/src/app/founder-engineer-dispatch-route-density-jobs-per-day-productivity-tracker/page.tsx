import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { productivity_status: string; routes: number; pct: number };
type RegionRow = {
  region: string;
  total_routes: number;
  jobs_planned: number;
  jobs_completed: number;
  avg_jobs_per_day: number;
  avg_first_visit_success_pct: number;
  overtime_routes: number;
  below_target: number;
  on_or_above_pct: number;
};
type MatrixRow = {
  region: string;
  route_efficiency: string;
  routes: number;
  avg_jobs_per_day: number;
  avg_travel_km: number;
};
type TrendRow = {
  month: string;
  routes: number;
  jobs_completed: number;
  avg_jobs_per_day: number;
  avg_first_visit_success_pct: number;
  overtime_routes: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_impact_pct: number;
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
  finding_category: string;
  findings: number;
  open_findings: number;
  avg_impact_pct: number;
  total_cost_rupees: number;
};
type RiskRow = {
  engineer_name: string;
  route_code: string;
  region: string;
  route_date: string;
  productivity_status: string;
  route_efficiency: string;
  jobs_planned: number | null;
  jobs_completed: number | null;
  jobs_per_day: number | null;
  first_visit_success_pct: number | null;
  overtime_flag: boolean | null;
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
    supabase.rpc('founder_r3472_productivity_status_rollup'),
    supabase.rpc('founder_r3472_region_scorecard'),
    supabase.rpc('founder_r3472_region_efficiency_matrix'),
    supabase.rpc('founder_r3472_monthly_productivity_trend'),
    supabase.rpc('founder_r3472_capa_status_board'),
    supabase.rpc('founder_r3472_root_cause_pareto'),
    supabase.rpc('founder_r3472_productivity_impact_digest'),
    supabase.rpc('founder_r3472_high_risk_queue'),
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
    { key: 'productivity_status', header: 'Productivity Status' },
    { key: 'routes', header: 'Routes' },
    { key: 'pct', header: 'Share %' },
  ];

  const regionCols: Column<RegionRow>[] = [
    { key: 'region', header: 'Region' },
    { key: 'total_routes', header: 'Routes' },
    { key: 'jobs_planned', header: 'Jobs Planned' },
    { key: 'jobs_completed', header: 'Jobs Completed' },
    { key: 'avg_jobs_per_day', header: 'Avg Jobs/Day' },
    { key: 'avg_first_visit_success_pct', header: 'Avg FVS %' },
    { key: 'overtime_routes', header: 'Overtime Routes' },
    { key: 'below_target', header: 'Below Target' },
    { key: 'on_or_above_pct', header: 'On/Above %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'region', header: 'Region' },
    { key: 'route_efficiency', header: 'Route Efficiency' },
    { key: 'routes', header: 'Routes' },
    { key: 'avg_jobs_per_day', header: 'Avg Jobs/Day' },
    { key: 'avg_travel_km', header: 'Avg Travel km' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'month', header: 'Month' },
    { key: 'routes', header: 'Routes' },
    { key: 'jobs_completed', header: 'Jobs Completed' },
    { key: 'avg_jobs_per_day', header: 'Avg Jobs/Day' },
    { key: 'avg_first_visit_success_pct', header: 'Avg FVS %' },
    { key: 'overtime_routes', header: 'Overtime Routes' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_impact_pct', header: 'Avg Impact %' },
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
    { key: 'finding_category', header: 'Finding Category' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'avg_impact_pct', header: 'Avg Impact %' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'route_code', header: 'Route' },
    { key: 'region', header: 'Region' },
    { key: 'route_date', header: 'Date' },
    { key: 'productivity_status', header: 'Status' },
    { key: 'route_efficiency', header: 'Efficiency' },
    { key: 'jobs_planned', header: 'Planned' },
    { key: 'jobs_completed', header: 'Completed' },
    { key: 'jobs_per_day', header: 'Jobs/Day' },
    { key: 'first_visit_success_pct', header: 'FVS %' },
    { key: 'overtime_flag', header: 'Overtime' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Dispatch Route-Density / Jobs-Per-Day Productivity Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Field dispatch productivity log — engineer &times; region &times; route date &times; jobs
        planned/completed &times; travel km &amp; hours &times; on-site hours &times; jobs-per-day
        &times; first-visit-success &times; route efficiency &times; productivity status &times;
        overtime &amp; CAPA closure. Founder-gated view: productivity-status mix, region scorecards,
        route-efficiency matrix, root-cause pareto, and productivity-impact digest across the field
        engineer fleet.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Productivity status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No routes logged yet."
          rowKey={(r, i) => String(r.productivity_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Region productivity scorecard</h2>
        <DataTable
          rows={regionRows}
          columns={regionCols}
          emptyMessage="No region rollups."
          rowKey={(r, i) => String(r.region ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Region &times; route-efficiency matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No routes by efficiency."
          rowKey={(r, i) => `${r.region}-${r.route_efficiency}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly jobs-per-day trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Productivity-impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No productivity-impact rollups."
          rowKey={(r, i) => String(r.finding_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk route queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk routes."
          rowKey={(r, i) => `${r.route_code}-${r.route_date}-${i}`}
        />
      </section>
    </main>
  );
}
