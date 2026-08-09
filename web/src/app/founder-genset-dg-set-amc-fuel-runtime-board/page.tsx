import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { readiness_status: string; gensets: number; pct: number };
type SiteRow = {
  site_name: string;
  gensets: number;
  ready: number;
  service_due: number;
  amc_expiring: number;
  start_failures: number;
  not_operational: number;
  total_runtime_hours: number;
  avg_fuel_per_hour: number;
  ready_pct: number;
};
type MatrixRow = {
  genset_class: string;
  readiness_status: string;
  gensets: number;
  total_runtime_hours: number;
  avg_fuel_per_hour: number;
};
type TrendRow = {
  period_month: string;
  gensets: number;
  total_runtime_hours: number;
  total_fuel_litres: number;
  avg_fuel_per_hour: number;
  load_tests_done: number;
  start_failures: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  avg_cost_rupees: number;
  overdue_or_escalated: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_rupees: number;
  pct: number;
};
type FuelRow = {
  genset_class: string;
  gensets: number;
  avg_capacity_kva: number;
  total_runtime_hours: number;
  total_fuel_litres: number;
  avg_fuel_per_hour: number;
  worsening: number;
};
type RiskRow = {
  site_name: string;
  genset_code: string;
  genset_class: string;
  period_month: string;
  readiness_status: string;
  starts_failed: number;
  battery_health_pct: number | null;
  days_to_amc_expiry: number | null;
  trend_dir: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    siteRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    fuelRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3688_readiness_status_rollup'),
    supabase.rpc('founder_r3688_site_scorecard'),
    supabase.rpc('founder_r3688_class_status_matrix'),
    supabase.rpc('founder_r3688_monthly_runtime_fuel_trend'),
    supabase.rpc('founder_r3688_capa_status_board'),
    supabase.rpc('founder_r3688_root_cause_pareto'),
    supabase.rpc('founder_r3688_fuel_efficiency_digest'),
    supabase.rpc('founder_r3688_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const siteRows: SiteRow[] = (siteRes.data as SiteRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const fuelRows: FuelRow[] = (fuelRes.data as FuelRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'readiness_status', header: 'Readiness Status' },
    { key: 'gensets', header: 'Gensets' },
    { key: 'pct', header: 'Share %' },
  ];

  const siteCols: Column<SiteRow>[] = [
    { key: 'site_name', header: 'Site' },
    { key: 'gensets', header: 'Gensets' },
    { key: 'ready', header: 'Ready' },
    { key: 'service_due', header: 'Service Due' },
    { key: 'amc_expiring', header: 'AMC Expiring' },
    { key: 'start_failures', header: 'Start Failures' },
    { key: 'not_operational', header: 'Not Operational' },
    { key: 'total_runtime_hours', header: 'Runtime Hrs' },
    { key: 'avg_fuel_per_hour', header: 'Avg Fuel L/hr' },
    { key: 'ready_pct', header: 'Ready %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'genset_class', header: 'Genset Class' },
    { key: 'readiness_status', header: 'Readiness Status' },
    { key: 'gensets', header: 'Gensets' },
    { key: 'total_runtime_hours', header: 'Runtime Hrs' },
    { key: 'avg_fuel_per_hour', header: 'Avg Fuel L/hr' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'gensets', header: 'Gensets' },
    { key: 'total_runtime_hours', header: 'Runtime Hrs' },
    { key: 'total_fuel_litres', header: 'Fuel Litres' },
    { key: 'avg_fuel_per_hour', header: 'Avg Fuel L/hr' },
    { key: 'load_tests_done', header: 'Load Tests Done' },
    { key: 'start_failures', header: 'Start Failures' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_or_escalated', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const fuelCols: Column<FuelRow>[] = [
    { key: 'genset_class', header: 'Genset Class' },
    { key: 'gensets', header: 'Gensets' },
    { key: 'avg_capacity_kva', header: 'Avg kVA' },
    { key: 'total_runtime_hours', header: 'Runtime Hrs' },
    { key: 'total_fuel_litres', header: 'Fuel Litres' },
    { key: 'avg_fuel_per_hour', header: 'Avg Fuel L/hr' },
    { key: 'worsening', header: 'Worsening Trend' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'site_name', header: 'Site' },
    { key: 'genset_code', header: 'Genset' },
    { key: 'genset_class', header: 'Class' },
    { key: 'period_month', header: 'Month' },
    { key: 'readiness_status', header: 'Readiness' },
    { key: 'starts_failed', header: 'Starts Failed' },
    { key: 'battery_health_pct', header: 'Battery %' },
    { key: 'days_to_amc_expiry', header: 'Days to AMC Expiry' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Genset / DG-Set AMC, Fuel &amp; Runtime Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Own-premises DG-set fleet log — genset class (below 62 kVA &mdash; above 320 kVA &amp;
        portable) &times; site &times; runtime hours &times; fuel consumed &times; fuel per hour
        &times; AMC validity &times; load test &times; battery health &times; start failures
        &amp; CAPA closure. Founder-gated view: readiness rollups, site scorecards, monthly
        runtime/fuel trend, root-cause pareto, and fuel-efficiency digest across Delhi, Bhiwandi
        &amp; Chennai warehouses.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Readiness status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No genset logs yet."
          rowKey={(r, i) => String(r.readiness_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Site genset scorecard</h2>
        <DataTable
          rows={siteRows}
          columns={siteCols}
          emptyMessage="No site rollups."
          rowKey={(r, i) => String(r.site_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Genset class &times; readiness matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No class rollups."
          rowKey={(r, i) => `${r.genset_class}-${r.readiness_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly runtime &amp; fuel trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.period_month ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA status board</h2>
        <DataTable
          rows={capaRows}
          columns={capaCols}
          emptyMessage="No CAPA actions."
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Fuel efficiency digest</h2>
        <DataTable
          rows={fuelRows}
          columns={fuelCols}
          emptyMessage="No fuel-efficiency rollups."
          rowKey={(r, i) => String(r.genset_class ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk genset queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk gensets."
          rowKey={(r, i) => `${r.genset_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
