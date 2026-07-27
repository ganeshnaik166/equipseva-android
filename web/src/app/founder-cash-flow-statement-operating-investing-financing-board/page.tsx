import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { flow_status: string; line_items: number; pct: number };
type ActivityRow = {
  activity_type: string;
  line_items: number;
  total_inflow_rupees: number;
  total_outflow_rupees: number;
  total_net_rupees: number;
  total_budget_net_rupees: number;
  total_variance_rupees: number;
  favorable: number;
  adverse: number;
};
type MatrixRow = {
  activity_type: string;
  flow_status: string;
  line_items: number;
  total_net_rupees: number;
  total_variance_rupees: number;
};
type TrendRow = {
  period_month: string;
  line_items: number;
  total_inflow_rupees: number;
  total_outflow_rupees: number;
  net_change_rupees: number;
  budget_net_rupees: number;
  variance_rupees: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  total_impact_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_impact_rupees: number;
  pct: number;
};
type DigestRow = {
  flow_status: string;
  line_items: number;
  total_inflow_rupees: number;
  total_outflow_rupees: number;
  total_net_rupees: number;
  total_variance_rupees: number;
};
type RiskRow = {
  line_item: string;
  period_month: string;
  activity_type: string;
  flow_status: string;
  trend_dir: string;
  inflow_rupees: number;
  outflow_rupees: number;
  net_flow_rupees: number;
  budget_net_rupees: number;
  variance_rupees: number;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    activityRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3505_flow_status_rollup'),
    supabase.rpc('founder_r3505_activity_type_scorecard'),
    supabase.rpc('founder_r3505_activity_flow_status_matrix'),
    supabase.rpc('founder_r3505_monthly_cash_flow_trend'),
    supabase.rpc('founder_r3505_capa_status_board'),
    supabase.rpc('founder_r3505_root_cause_pareto'),
    supabase.rpc('founder_r3505_net_flow_impact_digest'),
    supabase.rpc('founder_r3505_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const activityRows: ActivityRow[] = (activityRes.data as ActivityRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'flow_status', header: 'Flow Status' },
    { key: 'line_items', header: 'Line Items' },
    { key: 'pct', header: 'Share %' },
  ];

  const activityCols: Column<ActivityRow>[] = [
    { key: 'activity_type', header: 'Activity' },
    { key: 'line_items', header: 'Line Items' },
    { key: 'total_inflow_rupees', header: 'Inflow (INR)' },
    { key: 'total_outflow_rupees', header: 'Outflow (INR)' },
    { key: 'total_net_rupees', header: 'Net Flow (INR)' },
    { key: 'total_budget_net_rupees', header: 'Budget Net (INR)' },
    { key: 'total_variance_rupees', header: 'Variance (INR)' },
    { key: 'favorable', header: 'Favorable' },
    { key: 'adverse', header: 'Unfavorable / Critical' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'activity_type', header: 'Activity' },
    { key: 'flow_status', header: 'Flow Status' },
    { key: 'line_items', header: 'Line Items' },
    { key: 'total_net_rupees', header: 'Net Flow (INR)' },
    { key: 'total_variance_rupees', header: 'Variance (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Period' },
    { key: 'line_items', header: 'Line Items' },
    { key: 'total_inflow_rupees', header: 'Inflow (INR)' },
    { key: 'total_outflow_rupees', header: 'Outflow (INR)' },
    { key: 'net_change_rupees', header: 'Net Change (INR)' },
    { key: 'budget_net_rupees', header: 'Budget Net (INR)' },
    { key: 'variance_rupees', header: 'Variance (INR)' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'flow_status', header: 'Flow Status' },
    { key: 'line_items', header: 'Line Items' },
    { key: 'total_inflow_rupees', header: 'Inflow (INR)' },
    { key: 'total_outflow_rupees', header: 'Outflow (INR)' },
    { key: 'total_net_rupees', header: 'Net Flow (INR)' },
    { key: 'total_variance_rupees', header: 'Variance (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'line_item', header: 'Line Item' },
    { key: 'period_month', header: 'Period' },
    { key: 'activity_type', header: 'Activity' },
    { key: 'flow_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'inflow_rupees', header: 'Inflow (INR)' },
    { key: 'outflow_rupees', header: 'Outflow (INR)' },
    { key: 'net_flow_rupees', header: 'Net Flow (INR)' },
    { key: 'budget_net_rupees', header: 'Budget Net (INR)' },
    { key: 'variance_rupees', header: 'Variance (INR)' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Cash-Flow Statement (Operating / Investing / Financing) Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder cash-flow statement &mdash; line-item level waterfall across operating, investing
        &amp; financing activities &times; period month &times; inflow &times; outflow &times; net
        flow &times; budget net &times; variance &times; flow status &times; trend direction &amp;
        CAPA closure. Founder-gated view: flow-status distribution, activity-type scorecard,
        activity &times; flow-status matrix, monthly net-change trend, CAPA status board, root-cause
        pareto, net-flow impact digest, and the high-risk (critical / unfavorable / worsening) queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Flow-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No cash-flow line items logged yet."
          rowKey={(r, i) => String(r.flow_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Activity-type scorecard</h2>
        <DataTable
          rows={activityRows}
          columns={activityCols}
          emptyMessage="No activity rollups."
          rowKey={(r, i) => String(r.activity_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Activity &times; flow-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No matrix data."
          rowKey={(r, i) => `${r.activity_type}-${r.flow_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly cash-flow trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root-cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Net-flow impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No net-flow impact data."
          rowKey={(r, i) => String(r.flow_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk cash-flow queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk line items."
          rowKey={(r, i) => `${r.line_item}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
