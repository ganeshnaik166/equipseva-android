import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { realization_status: string; lines: number; pct: number };
type LineRow = {
  product_line: string;
  lines: number;
  fully_passed: number;
  partially_passed: number;
  absorbed_eroded: number;
  avg_cost_increase_pct: number;
  avg_realized_increase_pct: number;
  avg_pass_through_ratio_pct: number;
  total_revenue_impact_rupees: number;
};
type MatrixRow = {
  product_line: string;
  realization_status: string;
  lines: number;
  avg_pass_through_ratio_pct: number;
  total_revenue_impact_rupees: number;
};
type TrendRow = {
  period_month: string;
  lines: number;
  avg_cost_increase_pct: number;
  avg_realized_increase_pct: number;
  avg_pass_through_ratio_pct: number;
  total_revenue_impact_rupees: number;
  eroded_or_absorbed: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_margin_impact_pct: number;
  total_recovery_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_recovery_rupees: number;
  pct: number;
};
type DigestRow = {
  realization_status: string;
  lines: number;
  avg_margin_before_pct: number;
  avg_margin_after_pct: number;
  avg_margin_delta_pct: number;
  total_revenue_impact_rupees: number;
};
type RiskRow = {
  product_line: string;
  pricing_ref: string;
  customer_segment: string;
  region: string;
  period_month: string;
  cost_increase_pct: number | null;
  realized_increase_pct: number | null;
  pass_through_ratio_pct: number | null;
  margin_before_pct: number | null;
  margin_after_pct: number | null;
  revenue_impact_rupees: number | null;
  realization_status: string;
  trend_dir: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    lineRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3565_realization_status_rollup'),
    supabase.rpc('founder_r3565_product_line_scorecard'),
    supabase.rpc('founder_r3565_line_status_matrix'),
    supabase.rpc('founder_r3565_monthly_passthru_trend'),
    supabase.rpc('founder_r3565_capa_status_board'),
    supabase.rpc('founder_r3565_root_cause_pareto'),
    supabase.rpc('founder_r3565_margin_impact_digest'),
    supabase.rpc('founder_r3565_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const lineRows: LineRow[] = (lineRes.data as LineRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'realization_status', header: 'Realization Status' },
    { key: 'lines', header: 'Lines' },
    { key: 'pct', header: 'Share %' },
  ];

  const lineCols: Column<LineRow>[] = [
    { key: 'product_line', header: 'Product Line' },
    { key: 'lines', header: 'Lines' },
    { key: 'fully_passed', header: 'Fully Passed' },
    { key: 'partially_passed', header: 'Partially' },
    { key: 'absorbed_eroded', header: 'Absorbed / Eroded' },
    { key: 'avg_cost_increase_pct', header: 'Avg Cost Inc %' },
    { key: 'avg_realized_increase_pct', header: 'Avg Realized %' },
    { key: 'avg_pass_through_ratio_pct', header: 'Avg Pass-Through %' },
    { key: 'total_revenue_impact_rupees', header: 'Rev Impact (INR)' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'product_line', header: 'Product Line' },
    { key: 'realization_status', header: 'Realization Status' },
    { key: 'lines', header: 'Lines' },
    { key: 'avg_pass_through_ratio_pct', header: 'Avg Pass-Through %' },
    { key: 'total_revenue_impact_rupees', header: 'Rev Impact (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'lines', header: 'Lines' },
    { key: 'avg_cost_increase_pct', header: 'Avg Cost Inc %' },
    { key: 'avg_realized_increase_pct', header: 'Avg Realized %' },
    { key: 'avg_pass_through_ratio_pct', header: 'Avg Pass-Through %' },
    { key: 'total_revenue_impact_rupees', header: 'Rev Impact (INR)' },
    { key: 'eroded_or_absorbed', header: 'Eroded / Absorbed' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_margin_impact_pct', header: 'Avg Margin Impact %' },
    { key: 'total_recovery_rupees', header: 'Recovery (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_recovery_rupees', header: 'Recovery (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'realization_status', header: 'Realization Status' },
    { key: 'lines', header: 'Lines' },
    { key: 'avg_margin_before_pct', header: 'Avg Margin Before %' },
    { key: 'avg_margin_after_pct', header: 'Avg Margin After %' },
    { key: 'avg_margin_delta_pct', header: 'Avg Margin Delta %' },
    { key: 'total_revenue_impact_rupees', header: 'Rev Impact (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'product_line', header: 'Product Line' },
    { key: 'pricing_ref', header: 'Pricing Ref' },
    { key: 'customer_segment', header: 'Segment' },
    { key: 'region', header: 'Region' },
    { key: 'period_month', header: 'Month' },
    { key: 'cost_increase_pct', header: 'Cost Inc %' },
    { key: 'realized_increase_pct', header: 'Realized %' },
    { key: 'pass_through_ratio_pct', header: 'Pass-Through %' },
    { key: 'margin_before_pct', header: 'Margin Before %' },
    { key: 'margin_after_pct', header: 'Margin After %' },
    { key: 'revenue_impact_rupees', header: 'Rev Impact (INR)' },
    { key: 'realization_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Price-Increase Pass-Through / Realization Margin Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Cost-inflation price-increase pass-through realization &amp; margin protection per product
        line &mdash; product line &times; customer segment &times; region &times; cost increase %
        &times; list increase % &times; realized increase % &times; pass-through ratio &times;
        margin before/after &times; revenue impact &amp; CAPA closure. Founder-gated view:
        realization-status mix, product-line scorecards, root-cause pareto, and the margin-impact
        digest across lines whose increases were absorbed or eroded.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Realization status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No pass-through lines logged yet."
          rowKey={(r, i) => String(r.realization_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Product-line scorecard</h2>
        <DataTable
          rows={lineRows}
          columns={lineCols}
          emptyMessage="No product-line rollups."
          rowKey={(r, i) => String(r.product_line ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Product line &times; realization status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No lines by realization status."
          rowKey={(r, i) => `${r.product_line}-${r.realization_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly pass-through trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Margin-impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No margin-impact rollups."
          rowKey={(r, i) => String(r.realization_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk margin queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk lines."
          rowKey={(r, i) => `${r.pricing_ref}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
