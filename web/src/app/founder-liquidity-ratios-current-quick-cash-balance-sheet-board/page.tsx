import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { liquidity_status: string; snapshots: number; pct: number };
type ScoreRow = {
  business_unit: string;
  snapshots: number;
  avg_current_ratio: number;
  avg_quick_ratio: number;
  avg_cash_ratio: number;
  worst_current_ratio: number;
  below_target: number;
  stressed_count: number;
};
type MatrixRow = {
  business_unit: string;
  liquidity_status: string;
  snapshots: number;
  avg_current_ratio: number;
};
type TrendRow = {
  period_month: string;
  snapshots: number;
  avg_current_ratio: number;
  avg_quick_ratio: number;
  avg_cash_ratio: number;
  stressed_count: number;
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
  liquidity_status: string;
  snapshots: number;
  total_current_assets_rupees: number;
  total_current_liabilities_rupees: number;
  net_working_capital_rupees: number;
  total_cash_rupees: number;
};
type RiskRow = {
  business_unit: string;
  period_month: string;
  current_ratio: number;
  quick_ratio: number;
  cash_ratio: number;
  target_current_ratio: number;
  liquidity_status: string;
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
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3596_liquidity_status_rollup'),
    supabase.rpc('founder_r3596_business_unit_scorecard'),
    supabase.rpc('founder_r3596_business_unit_status_matrix'),
    supabase.rpc('founder_r3596_monthly_current_ratio_trend'),
    supabase.rpc('founder_r3596_capa_status_board'),
    supabase.rpc('founder_r3596_root_cause_pareto'),
    supabase.rpc('founder_r3596_liquidity_impact_digest'),
    supabase.rpc('founder_r3596_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const scoreRows: ScoreRow[] = (scoreRes.data as ScoreRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'liquidity_status', header: 'Liquidity Status' },
    { key: 'snapshots', header: 'Snapshots' },
    { key: 'pct', header: 'Share %' },
  ];

  const scoreCols: Column<ScoreRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'snapshots', header: 'Snapshots' },
    { key: 'avg_current_ratio', header: 'Avg Current' },
    { key: 'avg_quick_ratio', header: 'Avg Quick' },
    { key: 'avg_cash_ratio', header: 'Avg Cash' },
    { key: 'worst_current_ratio', header: 'Worst Current' },
    { key: 'below_target', header: 'Below Target' },
    { key: 'stressed_count', header: 'Stressed / Distressed' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'liquidity_status', header: 'Liquidity Status' },
    { key: 'snapshots', header: 'Snapshots' },
    { key: 'avg_current_ratio', header: 'Avg Current Ratio' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'snapshots', header: 'Snapshots' },
    { key: 'avg_current_ratio', header: 'Avg Current' },
    { key: 'avg_quick_ratio', header: 'Avg Quick' },
    { key: 'avg_cash_ratio', header: 'Avg Cash' },
    { key: 'stressed_count', header: 'Stressed / Distressed' },
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
    { key: 'liquidity_status', header: 'Liquidity Status' },
    { key: 'snapshots', header: 'Snapshots' },
    { key: 'total_current_assets_rupees', header: 'Current Assets (INR)' },
    { key: 'total_current_liabilities_rupees', header: 'Current Liabilities (INR)' },
    { key: 'net_working_capital_rupees', header: 'Net Working Capital (INR)' },
    { key: 'total_cash_rupees', header: 'Cash & Equiv (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'period_month', header: 'Month' },
    { key: 'current_ratio', header: 'Current' },
    { key: 'quick_ratio', header: 'Quick' },
    { key: 'cash_ratio', header: 'Cash' },
    { key: 'target_current_ratio', header: 'Target Current' },
    { key: 'liquidity_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Liquidity Ratios (Current / Quick / Cash) Balance-Sheet Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder balance-sheet liquidity board across business units &mdash; current, quick &amp; cash
        ratios vs targets &times; liquidity status (strong &rarr; distressed) &times; month-over-month
        trend &times; net-working-capital impact &amp; CAPA closure. Current ratio = current assets
        &divide; current liabilities; quick ratio excludes inventory; cash ratio uses cash &amp;
        equivalents only. Founder-gated view: status distribution, business-unit scorecards,
        root-cause pareto, and a high-risk (stressed / distressed) remediation queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Liquidity status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No liquidity snapshots logged yet."
          rowKey={(r, i) => String(r.liquidity_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Business-unit liquidity scorecard</h2>
        <DataTable
          rows={scoreRows}
          columns={scoreCols}
          emptyMessage="No business-unit rollups."
          rowKey={(r, i) => String(r.business_unit ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Business-unit &times; status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No snapshots by business unit."
          rowKey={(r, i) => `${r.business_unit}-${r.liquidity_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly current-ratio trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Liquidity-impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No liquidity-impact rollups."
          rowKey={(r, i) => String(r.liquidity_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk liquidity queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk snapshots."
          rowKey={(r, i) => `${r.business_unit}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
