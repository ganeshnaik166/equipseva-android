import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { efficiency_status: string; entries: number; pct: number };
type ScorecardRow = {
  business_unit: string;
  entries: number;
  high: number;
  on_target: number;
  below_target: number;
  underutilized: number;
  avg_roa_pct: number;
  avg_target_roa_pct: number;
  on_target_pct: number;
};
type MatrixRow = {
  business_unit: string;
  efficiency_status: string;
  entries: number;
  avg_roa_pct: number;
  avg_idle_asset_pct: number;
};
type TrendRow = {
  period_month: string;
  entries: number;
  avg_roa_pct: number;
  avg_target_roa_pct: number;
  avg_asset_turnover_ratio: number;
  avg_idle_asset_pct: number;
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
  business_unit: string;
  entries: number;
  avg_asset_turnover_ratio: number;
  avg_net_margin_pct: number;
  avg_idle_asset_pct: number;
  avg_revenue_per_asset_rupee: number;
};
type RiskRow = {
  business_unit: string;
  entry_code: string;
  period_month: string;
  efficiency_status: string;
  trend_dir: string;
  roa_pct: number;
  target_roa_pct: number;
  idle_asset_pct: number;
  asset_turnover_ratio: number;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    scorecardRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3605_efficiency_status_rollup'),
    supabase.rpc('founder_r3605_business_unit_scorecard'),
    supabase.rpc('founder_r3605_bu_efficiency_matrix'),
    supabase.rpc('founder_r3605_monthly_roa_trend'),
    supabase.rpc('founder_r3605_capa_status_board'),
    supabase.rpc('founder_r3605_root_cause_pareto'),
    supabase.rpc('founder_r3605_asset_efficiency_digest'),
    supabase.rpc('founder_r3605_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const scorecardRows: ScorecardRow[] = (scorecardRes.data as ScorecardRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'efficiency_status', header: 'Efficiency Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'pct', header: 'Share %' },
  ];

  const scorecardCols: Column<ScorecardRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'entries', header: 'Entries' },
    { key: 'high', header: 'High' },
    { key: 'on_target', header: 'On Target' },
    { key: 'below_target', header: 'Below Target' },
    { key: 'underutilized', header: 'Underutilized' },
    { key: 'avg_roa_pct', header: 'Avg ROA %' },
    { key: 'avg_target_roa_pct', header: 'Avg Target ROA %' },
    { key: 'on_target_pct', header: 'On-Target %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'efficiency_status', header: 'Efficiency Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'avg_roa_pct', header: 'Avg ROA %' },
    { key: 'avg_idle_asset_pct', header: 'Avg Idle Asset %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'entries', header: 'Entries' },
    { key: 'avg_roa_pct', header: 'Avg ROA %' },
    { key: 'avg_target_roa_pct', header: 'Avg Target ROA %' },
    { key: 'avg_asset_turnover_ratio', header: 'Avg Turnover' },
    { key: 'avg_idle_asset_pct', header: 'Avg Idle Asset %' },
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
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'entries', header: 'Entries' },
    { key: 'avg_asset_turnover_ratio', header: 'Avg Turnover' },
    { key: 'avg_net_margin_pct', header: 'Avg Net Margin %' },
    { key: 'avg_idle_asset_pct', header: 'Avg Idle Asset %' },
    { key: 'avg_revenue_per_asset_rupee', header: 'Avg Rev / Asset Rupee' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'entry_code', header: 'Entry' },
    { key: 'period_month', header: 'Month' },
    { key: 'efficiency_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'roa_pct', header: 'ROA %' },
    { key: 'target_roa_pct', header: 'Target ROA %' },
    { key: 'idle_asset_pct', header: 'Idle Asset %' },
    { key: 'asset_turnover_ratio', header: 'Turnover' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Return-on-Assets (ROA) / Asset-Efficiency Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated return-on-assets and asset-efficiency board across business units (AMC services,
        spare parts, projects, diagnostics, rentals &amp; turnkey installation). Tracks net profit,
        total &amp; average assets, ROA vs target, asset turnover, net margin, idle-asset %, and
        revenue-per-asset-rupee per BU &times; month, with an efficiency status verdict &amp; trend
        direction. Views: efficiency-status rollup, BU scorecard, BU &times; status matrix, monthly ROA
        trend, CAPA status board, root-cause pareto, asset-efficiency digest &amp; a high-risk
        (underutilized / below-target) remediation queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Efficiency-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No ROA entries logged yet."
          rowKey={(r, i) => String(r.efficiency_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Business-unit scorecard</h2>
        <DataTable
          rows={scorecardRows}
          columns={scorecardCols}
          emptyMessage="No business-unit rollups."
          rowKey={(r, i) => String(r.business_unit ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Business unit &times; efficiency status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No entries by business unit."
          rowKey={(r, i) => `${r.business_unit}-${r.efficiency_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly ROA trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Asset-efficiency digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No asset-efficiency rollups."
          rowKey={(r, i) => String(r.business_unit ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk entries."
          rowKey={(r, i) => `${r.entry_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
