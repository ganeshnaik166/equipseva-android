import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { adherence_status: string; routes: number; pct: number };
type RegionRow = {
  region: string;
  routes: number;
  on_route: number;
  deviating: number;
  off_plan: number;
  avg_adherence_pct: number;
  avg_km_variance_pct: number;
  total_fuel_cost_rupees: number;
  unauthorized_stops: number;
};
type MatrixRow = {
  route_type: string;
  adherence_status: string;
  routes: number;
  avg_adherence_pct: number;
  avg_km_variance_pct: number;
};
type TrendRow = {
  period_month: string;
  routes: number;
  avg_adherence_pct: number;
  avg_km_variance_pct: number;
  total_fuel_cost_rupees: number;
  unauthorized_stops: number;
  avg_delay_min: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  avg_excess_cost_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_excess_cost_rupees: number;
  pct: number;
};
type VarianceRow = {
  route_type: string;
  routes: number;
  total_planned_km: number;
  total_actual_km: number;
  excess_km: number;
  avg_km_variance_pct: number;
  total_fuel_cost_rupees: number;
};
type RiskRow = {
  route_code: string;
  route_name: string;
  region: string;
  period_month: string;
  route_type: string;
  adherence_status: string;
  trend_dir: string;
  adherence_pct: number;
  km_variance_pct: number;
  unauthorized_stops: number;
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
    varianceRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3668_adherence_status_rollup'),
    supabase.rpc('founder_r3668_region_scorecard'),
    supabase.rpc('founder_r3668_route_type_status_matrix'),
    supabase.rpc('founder_r3668_monthly_adherence_trend'),
    supabase.rpc('founder_r3668_capa_status_board'),
    supabase.rpc('founder_r3668_root_cause_pareto'),
    supabase.rpc('founder_r3668_km_variance_digest'),
    supabase.rpc('founder_r3668_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const regionRows: RegionRow[] = (regionRes.data as RegionRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const varianceRows: VarianceRow[] = (varianceRes.data as VarianceRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'adherence_status', header: 'Adherence Status' },
    { key: 'routes', header: 'Routes' },
    { key: 'pct', header: 'Share %' },
  ];

  const regionCols: Column<RegionRow>[] = [
    { key: 'region', header: 'Region' },
    { key: 'routes', header: 'Routes' },
    { key: 'on_route', header: 'On Route' },
    { key: 'deviating', header: 'Deviating' },
    { key: 'off_plan', header: 'Off Plan' },
    { key: 'avg_adherence_pct', header: 'Avg Adherence %' },
    { key: 'avg_km_variance_pct', header: 'Avg Km Var %' },
    { key: 'total_fuel_cost_rupees', header: 'Fuel Cost (INR)' },
    { key: 'unauthorized_stops', header: 'Unauth Stops' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'route_type', header: 'Route Type' },
    { key: 'adherence_status', header: 'Adherence Status' },
    { key: 'routes', header: 'Routes' },
    { key: 'avg_adherence_pct', header: 'Avg Adherence %' },
    { key: 'avg_km_variance_pct', header: 'Avg Km Var %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'routes', header: 'Routes' },
    { key: 'avg_adherence_pct', header: 'Avg Adherence %' },
    { key: 'avg_km_variance_pct', header: 'Avg Km Var %' },
    { key: 'total_fuel_cost_rupees', header: 'Fuel Cost (INR)' },
    { key: 'unauthorized_stops', header: 'Unauth Stops' },
    { key: 'avg_delay_min', header: 'Avg Delay (min)' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'avg_excess_cost_rupees', header: 'Avg Excess Cost (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_excess_cost_rupees', header: 'Total Excess Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const varianceCols: Column<VarianceRow>[] = [
    { key: 'route_type', header: 'Route Type' },
    { key: 'routes', header: 'Routes' },
    { key: 'total_planned_km', header: 'Planned Km' },
    { key: 'total_actual_km', header: 'Actual Km' },
    { key: 'excess_km', header: 'Excess Km' },
    { key: 'avg_km_variance_pct', header: 'Avg Km Var %' },
    { key: 'total_fuel_cost_rupees', header: 'Fuel Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'route_code', header: 'Route Code' },
    { key: 'route_name', header: 'Route' },
    { key: 'region', header: 'Region' },
    { key: 'period_month', header: 'Month' },
    { key: 'route_type', header: 'Type' },
    { key: 'adherence_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'adherence_pct', header: 'Adherence %' },
    { key: 'km_variance_pct', header: 'Km Var %' },
    { key: 'unauthorized_stops', header: 'Unauth Stops' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Delivery Route-Adherence / Optimization Compliance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Delivery &amp; field-visit route governance — route &times; region &times; period
        &times; trips on-route &times; adherence % &times; planned vs actual km &times; km
        variance &times; fuel cost &times; unauthorized stops &times; average delay across
        delivery vans, field-engineer beats, spare couriers, milk runs &amp; emergency
        dispatches. Founder-gated view: adherence-status rollups, region scorecards,
        km-variance digest, root-cause pareto &amp; CAPA closure for routes like
        Mumbai&mdash;Pune and Delhi&mdash;Gurgaon.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Adherence status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No route-adherence logs yet."
          rowKey={(r, i) => String(r.adherence_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Region adherence scorecard</h2>
        <DataTable
          rows={regionRows}
          columns={regionCols}
          emptyMessage="No region rollups."
          rowKey={(r, i) => String(r.region ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Route type &times; adherence status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No routes by type."
          rowKey={(r, i) => `${r.route_type}-${r.adherence_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly adherence trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Km-variance digest by route type</h2>
        <DataTable
          rows={varianceRows}
          columns={varianceCols}
          emptyMessage="No km-variance rollups."
          rowKey={(r, i) => String(r.route_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk route queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk routes."
          rowKey={(r, i) => `${r.route_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
