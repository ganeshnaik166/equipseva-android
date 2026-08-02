import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { otif_status: string; records: number; pct: number };
type RegionRow = {
  region: string;
  records: number;
  total_orders: number;
  total_otif_orders: number;
  avg_otif_pct: number;
  avg_target_pct: number;
  avg_delay_days: number;
  short_ship_incidents: number;
  expedite_cost_rupees: number;
  below_target: number;
};
type MatrixRow = {
  failure_driver: string;
  otif_status: string;
  records: number;
  avg_otif_pct: number;
  expedite_cost_rupees: number;
};
type TrendRow = {
  period_month: string;
  records: number;
  orders_shipped: number;
  otif_orders: number;
  otif_rate_pct: number;
  avg_delay_days: number;
  short_ship_incidents: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  avg_revenue_at_risk_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_revenue_at_risk_rupees: number;
  pct: number;
};
type DelayRow = {
  failure_driver: string;
  records: number;
  avg_delay_days: number;
  total_short_ship: number;
  total_expedite_cost_rupees: number;
  worst_otif_pct: number;
};
type RiskRow = {
  otif_ref: string;
  region: string;
  customer_segment: string;
  period_month: string;
  orders_shipped: number;
  otif_pct: number | null;
  target_otif_pct: number | null;
  avg_delay_days: number | null;
  failure_driver: string;
  otif_status: string;
  trend_dir: string;
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
    delayRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3665_otif_status_rollup'),
    supabase.rpc('founder_r3665_region_scorecard'),
    supabase.rpc('founder_r3665_failure_driver_status_matrix'),
    supabase.rpc('founder_r3665_monthly_otif_trend'),
    supabase.rpc('founder_r3665_capa_status_board'),
    supabase.rpc('founder_r3665_root_cause_pareto'),
    supabase.rpc('founder_r3665_delay_impact_digest'),
    supabase.rpc('founder_r3665_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const regionRows: RegionRow[] = (regionRes.data as RegionRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const delayRows: DelayRow[] = (delayRes.data as DelayRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'otif_status', header: 'OTIF Status' },
    { key: 'records', header: 'Records' },
    { key: 'pct', header: 'Share %' },
  ];

  const regionCols: Column<RegionRow>[] = [
    { key: 'region', header: 'Region' },
    { key: 'records', header: 'Records' },
    { key: 'total_orders', header: 'Orders Shipped' },
    { key: 'total_otif_orders', header: 'OTIF Orders' },
    { key: 'avg_otif_pct', header: 'Avg OTIF %' },
    { key: 'avg_target_pct', header: 'Avg Target %' },
    { key: 'avg_delay_days', header: 'Avg Delay (days)' },
    { key: 'short_ship_incidents', header: 'Short-Ship' },
    { key: 'expedite_cost_rupees', header: 'Expedite Cost (INR)' },
    { key: 'below_target', header: 'Below Target' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'failure_driver', header: 'Failure Driver' },
    { key: 'otif_status', header: 'OTIF Status' },
    { key: 'records', header: 'Records' },
    { key: 'avg_otif_pct', header: 'Avg OTIF %' },
    { key: 'expedite_cost_rupees', header: 'Expedite Cost (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'records', header: 'Records' },
    { key: 'orders_shipped', header: 'Orders Shipped' },
    { key: 'otif_orders', header: 'OTIF Orders' },
    { key: 'otif_rate_pct', header: 'OTIF Rate %' },
    { key: 'avg_delay_days', header: 'Avg Delay (days)' },
    { key: 'short_ship_incidents', header: 'Short-Ship' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'avg_revenue_at_risk_rupees', header: 'Avg Revenue at Risk (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_revenue_at_risk_rupees', header: 'Revenue at Risk (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const delayCols: Column<DelayRow>[] = [
    { key: 'failure_driver', header: 'Failure Driver' },
    { key: 'records', header: 'Records' },
    { key: 'avg_delay_days', header: 'Avg Delay (days)' },
    { key: 'total_short_ship', header: 'Short-Ship Incidents' },
    { key: 'total_expedite_cost_rupees', header: 'Expedite Cost (INR)' },
    { key: 'worst_otif_pct', header: 'Worst OTIF %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'otif_ref', header: 'Ref' },
    { key: 'region', header: 'Region' },
    { key: 'customer_segment', header: 'Segment' },
    { key: 'period_month', header: 'Month' },
    { key: 'orders_shipped', header: 'Orders' },
    { key: 'otif_pct', header: 'OTIF %' },
    { key: 'target_otif_pct', header: 'Target %' },
    { key: 'avg_delay_days', header: 'Avg Delay (days)' },
    { key: 'failure_driver', header: 'Failure Driver' },
    { key: 'otif_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        OTIF (On-Time-In-Full) Delivery Performance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Outbound delivery OTIF performance — region &times; customer segment &times; period month
        &times; orders shipped &times; on-time &times; in-full &times; OTIF % vs target &times; avg
        delay days &times; short-ship incidents &times; expedite cost &times; failure driver
        (stock-out, carrier delay, order processing, documentation, customer hold) &amp; CAPA
        closure. Founder-gated view: OTIF status rollup, region scorecards, monthly trend,
        root-cause pareto, and the poor/critical high-risk queue across Mumbai&mdash;Delhi,
        Chennai&mdash;Bengaluru and Kolkata&mdash;Guwahati lanes.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. OTIF status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No OTIF records logged yet."
          rowKey={(r, i) => String(r.otif_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Region OTIF scorecard</h2>
        <DataTable
          rows={regionRows}
          columns={regionCols}
          emptyMessage="No region rollups."
          rowKey={(r, i) => String(r.region ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Failure driver &times; OTIF status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No records by failure driver."
          rowKey={(r, i) => `${r.failure_driver}-${r.otif_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly OTIF trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Delay-impact digest</h2>
        <DataTable
          rows={delayRows}
          columns={delayCols}
          emptyMessage="No delay-impact rollups."
          rowKey={(r, i) => String(r.failure_driver ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk OTIF queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk records."
          rowKey={(r, i) => `${r.otif_ref}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
