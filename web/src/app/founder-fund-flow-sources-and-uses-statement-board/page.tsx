import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { flow_status: string; line_items: number; pct: number };
type CategoryRow = {
  flow_category: string;
  line_items: number;
  total_amount_rupees: number;
  surplus_items: number;
  deficit_items: number;
  strained_items: number;
  worsening_items: number;
  avg_net_position_rupees: number;
};
type MatrixRow = {
  flow_category: string;
  flow_type: string;
  flow_status: string;
  line_items: number;
  total_amount_rupees: number;
  avg_net_position_rupees: number;
};
type TrendRow = {
  period_month: string;
  line_items: number;
  source_amount_rupees: number;
  use_amount_rupees: number;
  net_amount_rupees: number;
  surplus_items: number;
  deficit_items: number;
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
type DigestRow = {
  trend_dir: string;
  line_items: number;
  total_amount_rupees: number;
  avg_net_position_rupees: number;
  min_net_position_rupees: number;
  deficit_or_strained_items: number;
};
type RiskRow = {
  flow_item: string;
  period_month: string;
  flow_category: string;
  source_type: string | null;
  use_type: string | null;
  amount_rupees: number;
  net_fund_position_rupees: number | null;
  flow_status: string;
  trend_dir: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    categoryRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3577_flow_status_rollup'),
    supabase.rpc('founder_r3577_flow_category_scorecard'),
    supabase.rpc('founder_r3577_source_use_status_matrix'),
    supabase.rpc('founder_r3577_monthly_fund_flow_trend'),
    supabase.rpc('founder_r3577_capa_status_board'),
    supabase.rpc('founder_r3577_root_cause_pareto'),
    supabase.rpc('founder_r3577_net_position_impact_digest'),
    supabase.rpc('founder_r3577_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const categoryRows: CategoryRow[] = (categoryRes.data as CategoryRow[]) ?? [];
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

  const categoryCols: Column<CategoryRow>[] = [
    { key: 'flow_category', header: 'Category' },
    { key: 'line_items', header: 'Line Items' },
    { key: 'total_amount_rupees', header: 'Total Amount (INR)' },
    { key: 'surplus_items', header: 'Surplus' },
    { key: 'deficit_items', header: 'Deficit' },
    { key: 'strained_items', header: 'Strained' },
    { key: 'worsening_items', header: 'Worsening' },
    { key: 'avg_net_position_rupees', header: 'Avg Net Position (INR)' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'flow_category', header: 'Category' },
    { key: 'flow_type', header: 'Source / Use Type' },
    { key: 'flow_status', header: 'Flow Status' },
    { key: 'line_items', header: 'Line Items' },
    { key: 'total_amount_rupees', header: 'Total Amount (INR)' },
    { key: 'avg_net_position_rupees', header: 'Avg Net Position (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Period' },
    { key: 'line_items', header: 'Line Items' },
    { key: 'source_amount_rupees', header: 'Sources (INR)' },
    { key: 'use_amount_rupees', header: 'Uses (INR)' },
    { key: 'net_amount_rupees', header: 'Net Flow (INR)' },
    { key: 'surplus_items', header: 'Surplus' },
    { key: 'deficit_items', header: 'Deficit / Strained' },
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

  const digestCols: Column<DigestRow>[] = [
    { key: 'trend_dir', header: 'Trend Direction' },
    { key: 'line_items', header: 'Line Items' },
    { key: 'total_amount_rupees', header: 'Total Amount (INR)' },
    { key: 'avg_net_position_rupees', header: 'Avg Net Position (INR)' },
    { key: 'min_net_position_rupees', header: 'Min Net Position (INR)' },
    { key: 'deficit_or_strained_items', header: 'Deficit / Strained' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'flow_item', header: 'Flow Item' },
    { key: 'period_month', header: 'Period' },
    { key: 'flow_category', header: 'Category' },
    { key: 'source_type', header: 'Source Type' },
    { key: 'use_type', header: 'Use Type' },
    { key: 'amount_rupees', header: 'Amount (INR)' },
    { key: 'net_fund_position_rupees', header: 'Net Position (INR)' },
    { key: 'flow_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Fund-Flow Sources-and-Uses Statement Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder fund-flow statement — sources (operations, debt, equity, asset sale, working-capital
        release) vs uses (capex, debt repayment, dividend, working-capital increase, investment) of
        funds &times; period month &times; amount &times; cumulative &amp; net fund position &times;
        flow status &times; trend direction &amp; CAPA closure. Founder-gated view: flow-status
        distribution, category scorecard, source/use &times; status matrix, monthly fund-flow trend,
        root-cause pareto, net-position impact digest, and a high-risk deficit/strained/worsening queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Flow-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No fund-flow entries logged yet."
          rowKey={(r, i) => String(r.flow_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Flow-category scorecard</h2>
        <DataTable
          rows={categoryRows}
          columns={categoryCols}
          emptyMessage="No category rollups."
          rowKey={(r, i) => String(r.flow_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Source / use type &times; flow-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No matrix data."
          rowKey={(r, i) => `${r.flow_category}-${r.flow_type}-${r.flow_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly fund-flow trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Net-position impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No net-position digest."
          rowKey={(r, i) => String(r.trend_dir ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk fund-flow queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk fund-flow items."
          rowKey={(r, i) => `${r.flow_item}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
