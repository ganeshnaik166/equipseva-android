import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { performance_status: string; units: number; pct: number };
type ScoreRow = {
  business_unit: string;
  periods: number;
  avg_net_margin_pct: number;
  avg_asset_turnover_ratio: number;
  avg_equity_multiplier: number;
  avg_roe_pct: number;
  avg_target_roe_pct: number;
  roe_gap_pct: number;
  underperform_periods: number;
};
type MatrixRow = {
  business_unit: string;
  performance_status: string;
  periods: number;
  avg_roe_pct: number;
};
type TrendRow = {
  period_month: string;
  units: number;
  avg_net_margin_pct: number;
  avg_asset_turnover_ratio: number;
  avg_equity_multiplier: number;
  avg_roe_pct: number;
  underperform_units: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_roe_uplift_bps: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_roe_uplift_bps: number;
  pct: number;
};
type DigestRow = {
  performance_status: string;
  units: number;
  avg_net_margin_pct: number;
  avg_asset_turnover_ratio: number;
  avg_equity_multiplier: number;
  avg_roe_pct: number;
};
type RiskRow = {
  business_unit: string;
  period_month: string;
  roe_pct: number;
  target_roe_pct: number;
  net_margin_pct: number;
  asset_turnover_ratio: number;
  equity_multiplier: number;
  performance_status: string;
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
    supabase.rpc('founder_r3597_performance_status_rollup'),
    supabase.rpc('founder_r3597_business_unit_scorecard'),
    supabase.rpc('founder_r3597_business_unit_status_matrix'),
    supabase.rpc('founder_r3597_monthly_roe_trend'),
    supabase.rpc('founder_r3597_capa_status_board'),
    supabase.rpc('founder_r3597_root_cause_pareto'),
    supabase.rpc('founder_r3597_roe_driver_digest'),
    supabase.rpc('founder_r3597_high_risk_queue'),
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
    { key: 'performance_status', header: 'Performance Status' },
    { key: 'units', header: 'Snapshots' },
    { key: 'pct', header: 'Share %' },
  ];

  const scoreCols: Column<ScoreRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'periods', header: 'Periods' },
    { key: 'avg_net_margin_pct', header: 'Avg Net Margin %' },
    { key: 'avg_asset_turnover_ratio', header: 'Avg Asset Turnover' },
    { key: 'avg_equity_multiplier', header: 'Avg Equity Mult' },
    { key: 'avg_roe_pct', header: 'Avg ROE %' },
    { key: 'avg_target_roe_pct', header: 'Avg Target ROE %' },
    { key: 'roe_gap_pct', header: 'ROE Gap %' },
    { key: 'underperform_periods', header: 'Underperform Periods' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'performance_status', header: 'Performance Status' },
    { key: 'periods', header: 'Periods' },
    { key: 'avg_roe_pct', header: 'Avg ROE %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'units', header: 'Units' },
    { key: 'avg_net_margin_pct', header: 'Avg Net Margin %' },
    { key: 'avg_asset_turnover_ratio', header: 'Avg Asset Turnover' },
    { key: 'avg_equity_multiplier', header: 'Avg Equity Mult' },
    { key: 'avg_roe_pct', header: 'Avg ROE %' },
    { key: 'underperform_units', header: 'Underperform Units' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_roe_uplift_bps', header: 'Avg ROE Uplift (bps)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_roe_uplift_bps', header: 'Total ROE Uplift (bps)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'performance_status', header: 'Performance Status' },
    { key: 'units', header: 'Snapshots' },
    { key: 'avg_net_margin_pct', header: 'Avg Net Margin %' },
    { key: 'avg_asset_turnover_ratio', header: 'Avg Asset Turnover' },
    { key: 'avg_equity_multiplier', header: 'Avg Equity Mult' },
    { key: 'avg_roe_pct', header: 'Avg ROE %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'period_month', header: 'Month' },
    { key: 'roe_pct', header: 'ROE %' },
    { key: 'target_roe_pct', header: 'Target %' },
    { key: 'net_margin_pct', header: 'Net Margin %' },
    { key: 'asset_turnover_ratio', header: 'Asset Turnover' },
    { key: 'equity_multiplier', header: 'Equity Mult' },
    { key: 'performance_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Return-on-Equity (ROE) / DuPont Decomposition Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated ROE view decomposing each business unit&apos;s return on equity into the three
        DuPont drivers &mdash; net margin &times; asset turnover &times; equity multiplier &mdash;
        against its equity hurdle. Tracks performance status (value-accretive &rarr; value-dilutive),
        trend direction, monthly driver trends, and CAPA value-improvement actions with expected ROE
        uplift in basis points. Underperformers (ROE &lt; target) surface in the high-risk queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Performance-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No ROE snapshots logged yet."
          rowKey={(r, i) => String(r.performance_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Business-unit ROE scorecard</h2>
        <DataTable
          rows={scoreRows}
          columns={scoreCols}
          emptyMessage="No business-unit rollups."
          rowKey={(r, i) => String(r.business_unit ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Business unit &times; performance-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No matrix data."
          rowKey={(r, i) => `${r.business_unit}-${r.performance_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly ROE / DuPont trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. ROE-driver digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No driver digest."
          rowKey={(r, i) => String(r.performance_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk ROE queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk units."
          rowKey={(r, i) => `${r.business_unit}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
