import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { performance_status: string; business_units: number; pct: number };
type ScorecardRow = {
  business_unit: string;
  periods: number;
  total_revenue_rupees: number;
  total_direct_cost_rupees: number;
  total_contribution_rupees: number;
  total_allocated_cost_rupees: number;
  total_segment_profit_rupees: number;
  avg_contribution_margin_pct: number;
  avg_segment_margin_pct: number;
};
type MatrixRow = {
  business_unit: string;
  performance_status: string;
  entries: number;
  total_segment_profit_rupees: number;
  avg_segment_margin_pct: number;
};
type TrendRow = {
  period_month: string;
  entries: number;
  total_revenue_rupees: number;
  total_segment_profit_rupees: number;
  avg_contribution_margin_pct: number;
  avg_segment_margin_pct: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_profit_impact_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_profit_impact_rupees: number;
  pct: number;
};
type ImpactRow = {
  profit_impact_class: string;
  findings: number;
  open_findings: number;
  total_profit_impact_rupees: number;
};
type RiskRow = {
  business_unit: string;
  period_month: string;
  performance_status: string;
  trend_dir: string;
  revenue_rupees: number | null;
  contribution_margin_pct: number | null;
  segment_margin_pct: number | null;
  segment_profit_rupees: number | null;
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
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3509_performance_status_rollup'),
    supabase.rpc('founder_r3509_business_unit_scorecard'),
    supabase.rpc('founder_r3509_bu_performance_matrix'),
    supabase.rpc('founder_r3509_monthly_margin_trend'),
    supabase.rpc('founder_r3509_capa_status_board'),
    supabase.rpc('founder_r3509_root_cause_pareto'),
    supabase.rpc('founder_r3509_profit_impact_digest'),
    supabase.rpc('founder_r3509_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const scorecardRows: ScorecardRow[] = (scorecardRes.data as ScorecardRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'performance_status', header: 'Performance Status' },
    { key: 'business_units', header: 'Entries' },
    { key: 'pct', header: 'Share %' },
  ];

  const scorecardCols: Column<ScorecardRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'periods', header: 'Periods' },
    { key: 'total_revenue_rupees', header: 'Revenue (INR)' },
    { key: 'total_direct_cost_rupees', header: 'Direct Cost (INR)' },
    { key: 'total_contribution_rupees', header: 'Contribution (INR)' },
    { key: 'total_allocated_cost_rupees', header: 'Allocated Cost (INR)' },
    { key: 'total_segment_profit_rupees', header: 'Segment Profit (INR)' },
    { key: 'avg_contribution_margin_pct', header: 'Avg CM %' },
    { key: 'avg_segment_margin_pct', header: 'Avg Seg Margin %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'performance_status', header: 'Performance Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_segment_profit_rupees', header: 'Segment Profit (INR)' },
    { key: 'avg_segment_margin_pct', header: 'Avg Seg Margin %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_revenue_rupees', header: 'Revenue (INR)' },
    { key: 'total_segment_profit_rupees', header: 'Segment Profit (INR)' },
    { key: 'avg_contribution_margin_pct', header: 'Avg CM %' },
    { key: 'avg_segment_margin_pct', header: 'Avg Seg Margin %' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_profit_impact_rupees', header: 'Avg Impact (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_profit_impact_rupees', header: 'Total Impact (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const impactCols: Column<ImpactRow>[] = [
    { key: 'profit_impact_class', header: 'Impact Class' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_profit_impact_rupees', header: 'Total Impact (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'period_month', header: 'Month' },
    { key: 'performance_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'revenue_rupees', header: 'Revenue (INR)' },
    { key: 'contribution_margin_pct', header: 'CM %' },
    { key: 'segment_margin_pct', header: 'Seg Margin %' },
    { key: 'segment_profit_rupees', header: 'Segment Profit (INR)' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Segment-Reporting / Business-Unit P&amp;L Contribution Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated segment &amp; business-unit P&amp;L contribution reporting &mdash; business unit
        &times; period &times; revenue &times; direct cost &times; contribution &times; allocated cost
        &times; segment profit &times; contribution margin &times; segment margin &times; performance
        status &times; trend &amp; CAPA remediation. Views: performance-status distribution, BU
        scorecards, BU &times; performance-status matrix, monthly segment-margin trend, root-cause
        pareto, profit-impact digest, and a high-risk queue of loss-making, underperforming &amp;
        worsening units.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Performance-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No BU P&L rows logged yet."
          rowKey={(r, i) => String(r.performance_status ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Business-unit &times; performance-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No matrix data."
          rowKey={(r, i) => `${r.business_unit}-${r.performance_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly segment-margin trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Profit-impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No profit-impact rollups."
          rowKey={(r, i) => String(r.profit_impact_class ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk BU queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk business units."
          rowKey={(r, i) => `${r.business_unit}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
