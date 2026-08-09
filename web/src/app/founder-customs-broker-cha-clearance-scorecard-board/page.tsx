import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { performance_status: string; scorecards: number; pct: number };
type BrokerRow = {
  broker_name: string;
  scorecards: number;
  shipments: number;
  avg_clearance_days: number;
  avg_first_time_pct: number;
  avg_query_rate_pct: number;
  penalty_incidents: number;
  total_spend_rupees: number;
  healthy_pct: number;
};
type MatrixRow = {
  shipment_mode: string;
  performance_status: string;
  scorecards: number;
  shipments: number;
  avg_clearance_days: number;
};
type TrendRow = {
  period_month: string;
  scorecards: number;
  shipments: number;
  avg_clearance_days: number;
  avg_first_time_pct: number;
  penalty_incidents: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_demurrage_cost_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_demurrage_cost_rupees: number;
  pct: number;
};
type DigestRow = {
  port_name: string;
  scorecards: number;
  avg_query_rate_pct: number;
  avg_doc_error_rate_pct: number;
  penalty_incidents: number;
  total_brokerage_spend_rupees: number;
};
type RiskRow = {
  broker_name: string;
  scorecard_code: string;
  port_name: string;
  period_month: string;
  shipment_mode: string;
  performance_status: string;
  trend_dir: string;
  avg_clearance_days: number;
  query_rate_pct: number | null;
  penalty_incidents: number;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    brokerRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3671_performance_status_rollup'),
    supabase.rpc('founder_r3671_broker_scorecard'),
    supabase.rpc('founder_r3671_mode_status_matrix'),
    supabase.rpc('founder_r3671_monthly_clearance_trend'),
    supabase.rpc('founder_r3671_capa_status_board'),
    supabase.rpc('founder_r3671_root_cause_pareto'),
    supabase.rpc('founder_r3671_query_doc_error_digest'),
    supabase.rpc('founder_r3671_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const brokerRows: BrokerRow[] = (brokerRes.data as BrokerRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'performance_status', header: 'Performance Status' },
    { key: 'scorecards', header: 'Scorecards' },
    { key: 'pct', header: 'Share %' },
  ];

  const brokerCols: Column<BrokerRow>[] = [
    { key: 'broker_name', header: 'Broker (CHA)' },
    { key: 'scorecards', header: 'Scorecards' },
    { key: 'shipments', header: 'Shipments' },
    { key: 'avg_clearance_days', header: 'Avg Clearance Days' },
    { key: 'avg_first_time_pct', header: 'Avg FTC %' },
    { key: 'avg_query_rate_pct', header: 'Avg Query %' },
    { key: 'penalty_incidents', header: 'Penalties' },
    { key: 'total_spend_rupees', header: 'Brokerage Spend (INR)' },
    { key: 'healthy_pct', header: 'Healthy %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'shipment_mode', header: 'Shipment Mode' },
    { key: 'performance_status', header: 'Status' },
    { key: 'scorecards', header: 'Scorecards' },
    { key: 'shipments', header: 'Shipments' },
    { key: 'avg_clearance_days', header: 'Avg Clearance Days' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'scorecards', header: 'Scorecards' },
    { key: 'shipments', header: 'Shipments' },
    { key: 'avg_clearance_days', header: 'Avg Clearance Days' },
    { key: 'avg_first_time_pct', header: 'Avg FTC %' },
    { key: 'penalty_incidents', header: 'Penalties' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_demurrage_cost_rupees', header: 'Avg Demurrage (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_demurrage_cost_rupees', header: 'Total Demurrage (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'port_name', header: 'Port' },
    { key: 'scorecards', header: 'Scorecards' },
    { key: 'avg_query_rate_pct', header: 'Avg Query %' },
    { key: 'avg_doc_error_rate_pct', header: 'Avg Doc Error %' },
    { key: 'penalty_incidents', header: 'Penalties' },
    { key: 'total_brokerage_spend_rupees', header: 'Brokerage Spend (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'broker_name', header: 'Broker (CHA)' },
    { key: 'scorecard_code', header: 'Scorecard' },
    { key: 'port_name', header: 'Port' },
    { key: 'period_month', header: 'Month' },
    { key: 'shipment_mode', header: 'Mode' },
    { key: 'performance_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'avg_clearance_days', header: 'Avg Clearance Days' },
    { key: 'query_rate_pct', header: 'Query %' },
    { key: 'penalty_incidents', header: 'Penalties' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customs-Broker (CHA) Clearance Scorecard Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Customs-broker (CHA) clearance performance scorecard — broker &times; port (Nhava Sheva,
        Chennai Port, Delhi Air Cargo) &times; period &times; shipments handled &times; avg
        clearance days vs target &times; first-time clearance % &times; query rate &times; penalty
        incidents &times; brokerage spend &times; doc-error rate &amp; CAPA closure. Founder-gated
        view: performance-status rollups, broker scorecards, mode &times; status matrix, monthly
        clearance trend, root-cause pareto, and the poor/critical high-risk queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Performance status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No scorecards logged yet."
          rowKey={(r, i) => String(r.performance_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Broker clearance scorecard</h2>
        <DataTable
          rows={brokerRows}
          columns={brokerCols}
          emptyMessage="No broker rollups."
          rowKey={(r, i) => String(r.broker_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Shipment mode &times; status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No scorecards by shipment mode."
          rowKey={(r, i) => `${r.shipment_mode}-${r.performance_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly clearance trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Query / doc-error digest by port</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No port-level digests."
          rowKey={(r, i) => String(r.port_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk broker queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk scorecards."
          rowKey={(r, i) => `${r.scorecard_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
