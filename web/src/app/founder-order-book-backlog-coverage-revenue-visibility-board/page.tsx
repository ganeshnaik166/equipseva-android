import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { coverage_status: string; lines: number; pct: number };
type ScoreRow = {
  product_line: string;
  total_lines: number;
  total_order_book_rupees: number;
  total_backlog_rupees: number;
  avg_coverage_months: number;
  avg_target_coverage_months: number;
  avg_aged_backlog_pct: number;
  healthy: number;
  critical_thin: number;
};
type MatrixRow = {
  product_line: string;
  coverage_status: string;
  lines: number;
  total_backlog_rupees: number;
  avg_coverage_months: number;
};
type TrendRow = {
  period_month: string;
  lines: number;
  total_order_book_rupees: number;
  total_backlog_rupees: number;
  avg_coverage_months: number;
  critical_thin: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_revenue_at_risk_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_revenue_at_risk_rupees: number;
  pct: number;
};
type ImpactRow = {
  revenue_impact: string;
  findings: number;
  open_findings: number;
  total_revenue_at_risk_rupees: number;
};
type RiskRow = {
  product_line: string;
  region: string;
  book_code: string;
  period_month: string;
  coverage_status: string;
  coverage_months: number;
  target_coverage_months: number;
  aged_backlog_pct: number;
  trend_dir: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    scoreRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3473_coverage_status_rollup'),
    supabase.rpc('founder_r3473_product_line_scorecard'),
    supabase.rpc('founder_r3473_product_line_coverage_matrix'),
    supabase.rpc('founder_r3473_monthly_coverage_trend'),
    supabase.rpc('founder_r3473_capa_status_board'),
    supabase.rpc('founder_r3473_root_cause_pareto'),
    supabase.rpc('founder_r3473_revenue_impact_digest'),
    supabase.rpc('founder_r3473_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const scoreRows: ScoreRow[] = (scoreRes.data as ScoreRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'coverage_status', header: 'Coverage Status' },
    { key: 'lines', header: 'Lines' },
    { key: 'pct', header: 'Share %' },
  ];

  const scoreCols: Column<ScoreRow>[] = [
    { key: 'product_line', header: 'Product Line' },
    { key: 'total_lines', header: 'Lines' },
    { key: 'total_order_book_rupees', header: 'Order Book (INR)' },
    { key: 'total_backlog_rupees', header: 'Backlog (INR)' },
    { key: 'avg_coverage_months', header: 'Avg Coverage Mo' },
    { key: 'avg_target_coverage_months', header: 'Avg Target Mo' },
    { key: 'avg_aged_backlog_pct', header: 'Avg Aged %' },
    { key: 'healthy', header: 'Healthy' },
    { key: 'critical_thin', header: 'Critical / Thin' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'product_line', header: 'Product Line' },
    { key: 'coverage_status', header: 'Coverage Status' },
    { key: 'lines', header: 'Lines' },
    { key: 'total_backlog_rupees', header: 'Backlog (INR)' },
    { key: 'avg_coverage_months', header: 'Avg Coverage Mo' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Period' },
    { key: 'lines', header: 'Lines' },
    { key: 'total_order_book_rupees', header: 'Order Book (INR)' },
    { key: 'total_backlog_rupees', header: 'Backlog (INR)' },
    { key: 'avg_coverage_months', header: 'Avg Coverage Mo' },
    { key: 'critical_thin', header: 'Critical / Thin' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_revenue_at_risk_rupees', header: 'Avg Revenue at Risk (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_revenue_at_risk_rupees', header: 'Total Revenue at Risk (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const impactCols: Column<ImpactRow>[] = [
    { key: 'revenue_impact', header: 'Revenue Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_revenue_at_risk_rupees', header: 'Total Revenue at Risk (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'product_line', header: 'Product Line' },
    { key: 'region', header: 'Region' },
    { key: 'book_code', header: 'Book Code' },
    { key: 'period_month', header: 'Period' },
    { key: 'coverage_status', header: 'Status' },
    { key: 'coverage_months', header: 'Coverage Mo' },
    { key: 'target_coverage_months', header: 'Target Mo' },
    { key: 'aged_backlog_pct', header: 'Aged %' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Order-Book / Backlog-Coverage &amp; Revenue-Visibility Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Forward revenue visibility per product line &times; region — order-book value, backlog value,
        monthly run-rate, coverage months vs target, aged-backlog % and coverage status
        (healthy &rarr; adequate &rarr; thin &rarr; critical) with monthly trend direction. Founder-gated
        view: coverage-status distribution, product-line scorecards, product-line &times; status matrix,
        monthly trend, plus CAPA recovery-action board, root-cause pareto and revenue-visibility impact
        digest across at-risk, deferred &amp; margin-pressure surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Coverage-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No coverage snapshots logged yet."
          rowKey={(r, i) => String(r.coverage_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Product-line coverage scorecard</h2>
        <DataTable
          rows={scoreRows}
          columns={scoreCols}
          emptyMessage="No product-line rollups."
          rowKey={(r, i) => String(r.product_line ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Product-line &times; coverage-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No lines by product line."
          rowKey={(r, i) => `${r.product_line}-${r.coverage_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly coverage trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.period_month ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA recovery-action board</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Revenue-visibility impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No revenue-impact rollups."
          rowKey={(r, i) => String(r.revenue_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk coverage queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk lines."
          rowKey={(r, i) => `${r.book_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
