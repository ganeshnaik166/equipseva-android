import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { variance_verdict: string; entries: number; pct: number };
type LineRow = {
  product_line: string;
  entries: number;
  favorable: number;
  neutral: number;
  unfavorable: number;
  total_variance_rupees: number;
  avg_variance_rupees: number;
  worsening: number;
};
type MatrixRow = {
  variance_driver: string;
  variance_verdict: string;
  entries: number;
  total_variance_rupees: number;
  avg_variance_rupees: number;
};
type TrendRow = {
  period_month: string;
  entries: number;
  favorable: number;
  unfavorable: number;
  total_variance_rupees: number;
  price_effect_rupees: number;
  cost_effect_rupees: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_impact_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_impact_rupees: number;
  pct: number;
};
type DigestRow = {
  effect_component: string;
  total_rupees: number;
  favorable_rows: number;
  adverse_rows: number;
};
type RiskRow = {
  product_line: string;
  variance_ref: string;
  period_month: string;
  variance_driver: string;
  variance_verdict: string;
  trend_dir: string;
  total_variance_rupees: number;
  actual_margin_rupees: number;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    lineRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3461_variance_verdict_rollup'),
    supabase.rpc('founder_r3461_product_line_scorecard'),
    supabase.rpc('founder_r3461_driver_verdict_matrix'),
    supabase.rpc('founder_r3461_monthly_variance_trend'),
    supabase.rpc('founder_r3461_capa_status_board'),
    supabase.rpc('founder_r3461_root_cause_pareto'),
    supabase.rpc('founder_r3461_margin_impact_digest'),
    supabase.rpc('founder_r3461_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const lineRows: LineRow[] = (lineRes.data as LineRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'variance_verdict', header: 'Verdict' },
    { key: 'entries', header: 'Entries' },
    { key: 'pct', header: 'Share %' },
  ];

  const lineCols: Column<LineRow>[] = [
    { key: 'product_line', header: 'Product Line' },
    { key: 'entries', header: 'Entries' },
    { key: 'favorable', header: 'Favorable' },
    { key: 'neutral', header: 'Neutral' },
    { key: 'unfavorable', header: 'Unfavorable' },
    { key: 'total_variance_rupees', header: 'Total Variance (INR)' },
    { key: 'avg_variance_rupees', header: 'Avg Variance (INR)' },
    { key: 'worsening', header: 'Worsening' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'variance_driver', header: 'Driver' },
    { key: 'variance_verdict', header: 'Verdict' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_variance_rupees', header: 'Total Variance (INR)' },
    { key: 'avg_variance_rupees', header: 'Avg Variance (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'entries', header: 'Entries' },
    { key: 'favorable', header: 'Favorable' },
    { key: 'unfavorable', header: 'Unfavorable' },
    { key: 'total_variance_rupees', header: 'Total Variance (INR)' },
    { key: 'price_effect_rupees', header: 'Price Effect (INR)' },
    { key: 'cost_effect_rupees', header: 'Cost Effect (INR)' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_impact_rupees', header: 'Avg Impact (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'effect_component', header: 'Effect Component' },
    { key: 'total_rupees', header: 'Total Effect (INR)' },
    { key: 'favorable_rows', header: 'Favorable Rows' },
    { key: 'adverse_rows', header: 'Adverse Rows' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'product_line', header: 'Product Line' },
    { key: 'variance_ref', header: 'Ref' },
    { key: 'period_month', header: 'Month' },
    { key: 'variance_driver', header: 'Driver' },
    { key: 'variance_verdict', header: 'Verdict' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'total_variance_rupees', header: 'Total Variance (INR)' },
    { key: 'actual_margin_rupees', header: 'Actual Margin (INR)' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Price-Volume-Mix Margin-Waterfall Variance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder gross-margin variance decomposition per product line &mdash; base vs actual margin
        bridged through price &times; volume &times; mix &times; cost effects, with total variance,
        driver classification (price-led, volume-led, mix-led, cost-led &amp; balanced), a
        favorable/neutral/unfavorable verdict, trend direction &amp; CAPA closure. Founder-gated view:
        verdict distribution, product-line scorecards, driver &times; verdict matrix, monthly variance
        trend, root-cause pareto, waterfall-component digest &amp; a high-risk variance queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Variance verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No variance entries logged yet."
          rowKey={(r, i) => String(r.variance_verdict ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Driver &times; verdict matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No driver breakdown."
          rowKey={(r, i) => `${r.variance_driver}-${r.variance_verdict}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly variance trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Margin-impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No margin-impact data."
          rowKey={(r, i) => String(r.effect_component ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk variance queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk variance rows."
          rowKey={(r, i) => `${r.variance_ref}-${i}`}
        />
      </section>
    </main>
  );
}
