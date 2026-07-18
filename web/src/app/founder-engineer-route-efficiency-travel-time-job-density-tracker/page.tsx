import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { route_verdict: string; route_days: number; pct: number };
type EngRow = {
  engineer_name: string;
  engineer_code: string;
  route_days: number;
  jobs_done: number;
  total_km: number;
  avg_travel_to_wrench: number;
  avg_jobs_per_day: number;
  total_fuel_rupees: number;
  optimal_days: number;
  efficiency_pct: number;
};
type ZoneRow = {
  zone_coverage: string;
  route_plan_source: string;
  route_days: number;
  avg_km: number;
  avg_travel_to_wrench: number;
  jobs_done: number;
};
type TrendRow = {
  day_date: string;
  routes: number;
  jobs_done: number;
  total_km: number;
  avg_travel_min: number;
  avg_wrench_min: number;
  avg_travel_to_wrench: number;
  fuel_rupees: number;
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
type RegRow = {
  regulatory_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  engineer_name: string;
  hospital_name: string;
  zone_name: string;
  day_date: string;
  route_verdict: string;
  travel_to_wrench: number;
  km_travelled: number;
  jobs_done: number;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    engRes,
    zoneRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3184_route_verdict_rollup'),
    supabase.rpc('founder_r3184_engineer_scorecard'),
    supabase.rpc('founder_r3184_zone_coverage_matrix'),
    supabase.rpc('founder_r3184_daily_trend'),
    supabase.rpc('founder_r3184_capa_status_board'),
    supabase.rpc('founder_r3184_root_cause_pareto'),
    supabase.rpc('founder_r3184_regulatory_impact_digest'),
    supabase.rpc('founder_r3184_high_risk_routes'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const engRows: EngRow[] = (engRes.data as EngRow[]) ?? [];
  const zoneRows: ZoneRow[] = (zoneRes.data as ZoneRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'route_verdict', header: 'Verdict' },
    { key: 'route_days', header: 'Route Days' },
    { key: 'pct', header: 'Share %' },
  ];

  const engCols: Column<EngRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'engineer_code', header: 'Code' },
    { key: 'route_days', header: 'Days' },
    { key: 'jobs_done', header: 'Jobs Done' },
    { key: 'total_km', header: 'Total km' },
    { key: 'avg_travel_to_wrench', header: 'Avg Travel/Wrench' },
    { key: 'avg_jobs_per_day', header: 'Jobs/Day' },
    { key: 'total_fuel_rupees', header: 'Fuel (INR)' },
    { key: 'optimal_days', header: 'Optimal Days' },
    { key: 'efficiency_pct', header: 'Efficiency %' },
  ];

  const zoneCols: Column<ZoneRow>[] = [
    { key: 'zone_coverage', header: 'Zone Coverage' },
    { key: 'route_plan_source', header: 'Plan Source' },
    { key: 'route_days', header: 'Route Days' },
    { key: 'avg_km', header: 'Avg km' },
    { key: 'avg_travel_to_wrench', header: 'Avg Travel/Wrench' },
    { key: 'jobs_done', header: 'Jobs Done' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'day_date', header: 'Date' },
    { key: 'routes', header: 'Routes' },
    { key: 'jobs_done', header: 'Jobs Done' },
    { key: 'total_km', header: 'Total km' },
    { key: 'avg_travel_min', header: 'Avg Travel Min' },
    { key: 'avg_wrench_min', header: 'Avg Wrench Min' },
    { key: 'avg_travel_to_wrench', header: 'Avg Ratio' },
    { key: 'fuel_rupees', header: 'Fuel (INR)' },
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

  const regCols: Column<RegRow>[] = [
    { key: 'regulatory_impact', header: 'Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'zone_name', header: 'Zone' },
    { key: 'day_date', header: 'Date' },
    { key: 'route_verdict', header: 'Verdict' },
    { key: 'travel_to_wrench', header: 'Travel/Wrench' },
    { key: 'km_travelled', header: 'km' },
    { key: 'jobs_done', header: 'Jobs Done' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Route-Efficiency, Travel-Time &amp; Job-Density Optimisation Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Field-service route log — engineer day &times; km travelled &times; travel/wrench minutes &times;
        job density &times; zone coverage &times; fuel cost &amp; CAPA closure. Founder-gated view:
        route verdicts, engineer scorecards, zone-coverage matrix, root-cause pareto, and
        high-risk route queue across the service fleet.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Route verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No route days logged yet."
          rowKey={(r, i) => String(r.route_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Engineer efficiency scorecard</h2>
        <DataTable
          rows={engRows}
          columns={engCols}
          emptyMessage="No engineer rollups."
          rowKey={(r, i) => String(r.engineer_code ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Zone coverage &times; plan source matrix</h2>
        <DataTable
          rows={zoneRows}
          columns={zoneCols}
          emptyMessage="No zone-coverage rollups."
          rowKey={(r, i) => `${r.zone_coverage}-${r.route_plan_source}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily fleet trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.day_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Regulatory &amp; contract impact digest</h2>
        <DataTable
          rows={regRows}
          columns={regCols}
          emptyMessage="No impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk route queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk routes."
          rowKey={(r, i) => `${r.engineer_name}-${r.day_date}-${i}`}
        />
      </section>
    </main>
  );
}
