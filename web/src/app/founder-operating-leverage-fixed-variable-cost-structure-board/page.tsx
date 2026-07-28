import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { leverage_status: string; lines: number; pct: number };
type LineRow = {
  business_line: string;
  snapshots: number;
  total_revenue_rupees: number;
  total_contribution_rupees: number;
  avg_contribution_margin_pct: number;
  total_operating_income_rupees: number;
  avg_dol: number | null;
  below_breakeven_count: number;
};
type MatrixRow = {
  business_line: string;
  leverage_status: string;
  snapshots: number;
  avg_contribution_margin_pct: number;
  total_operating_income_rupees: number;
};
type TrendRow = {
  period_month: string;
  snapshots: number;
  total_revenue_rupees: number;
  total_contribution_rupees: number;
  total_operating_income_rupees: number;
  avg_dol: number | null;
  below_breakeven_lines: number;
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
  business_line: string;
  total_contribution_rupees: number;
  total_fixed_cost_rupees: number;
  total_operating_income_rupees: number;
  avg_contribution_margin_pct: number;
  capa_impact_rupees: number;
};
type RiskRow = {
  business_line: string;
  snapshot_code: string;
  period_month: string;
  revenue_rupees: number;
  contribution_margin_pct: number;
  operating_income_rupees: number;
  degree_operating_leverage: number | null;
  breakeven_revenue_rupees: number;
  leverage_status: string;
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
    supabase.rpc('founder_r3569_leverage_status_rollup'),
    supabase.rpc('founder_r3569_business_line_scorecard'),
    supabase.rpc('founder_r3569_line_status_matrix'),
    supabase.rpc('founder_r3569_monthly_dol_trend'),
    supabase.rpc('founder_r3569_capa_status_board'),
    supabase.rpc('founder_r3569_root_cause_pareto'),
    supabase.rpc('founder_r3569_contribution_impact_digest'),
    supabase.rpc('founder_r3569_high_risk_queue'),
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
    { key: 'leverage_status', header: 'Leverage Status' },
    { key: 'lines', header: 'Lines' },
    { key: 'pct', header: 'Share %' },
  ];

  const lineCols: Column<LineRow>[] = [
    { key: 'business_line', header: 'Business Line' },
    { key: 'snapshots', header: 'Snapshots' },
    { key: 'total_revenue_rupees', header: 'Revenue (INR)' },
    { key: 'total_contribution_rupees', header: 'Contribution (INR)' },
    { key: 'avg_contribution_margin_pct', header: 'Avg CM %' },
    { key: 'total_operating_income_rupees', header: 'Op Income (INR)' },
    { key: 'avg_dol', header: 'Avg DOL' },
    { key: 'below_breakeven_count', header: 'Below Breakeven' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'business_line', header: 'Business Line' },
    { key: 'leverage_status', header: 'Leverage Status' },
    { key: 'snapshots', header: 'Snapshots' },
    { key: 'avg_contribution_margin_pct', header: 'Avg CM %' },
    { key: 'total_operating_income_rupees', header: 'Op Income (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'snapshots', header: 'Snapshots' },
    { key: 'total_revenue_rupees', header: 'Revenue (INR)' },
    { key: 'total_contribution_rupees', header: 'Contribution (INR)' },
    { key: 'total_operating_income_rupees', header: 'Op Income (INR)' },
    { key: 'avg_dol', header: 'Avg DOL' },
    { key: 'below_breakeven_lines', header: 'Below Breakeven' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'total_impact_rupees', header: 'Impact (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'business_line', header: 'Business Line' },
    { key: 'total_contribution_rupees', header: 'Contribution (INR)' },
    { key: 'total_fixed_cost_rupees', header: 'Fixed Cost (INR)' },
    { key: 'total_operating_income_rupees', header: 'Op Income (INR)' },
    { key: 'avg_contribution_margin_pct', header: 'Avg CM %' },
    { key: 'capa_impact_rupees', header: 'CAPA Impact (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'business_line', header: 'Business Line' },
    { key: 'snapshot_code', header: 'Snapshot' },
    { key: 'period_month', header: 'Month' },
    { key: 'revenue_rupees', header: 'Revenue (INR)' },
    { key: 'contribution_margin_pct', header: 'CM %' },
    { key: 'operating_income_rupees', header: 'Op Income (INR)' },
    { key: 'degree_operating_leverage', header: 'DOL' },
    { key: 'breakeven_revenue_rupees', header: 'Breakeven Rev (INR)' },
    { key: 'leverage_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Operating-Leverage / Fixed-Variable Cost-Structure Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder view of operating leverage across business lines &mdash; revenue split into fixed
        &amp; variable cost, contribution margin, operating income, degree of operating leverage
        (DOL) &amp; breakeven revenue per line. Lines are classed high-leverage, balanced,
        low-leverage or below-breakeven with an improving / stable / worsening trend. Includes
        cost-structure CAPA remediation: status board, root-cause pareto, contribution-impact
        digest, and a high-risk queue of below-breakeven &amp; high-DOL thin-margin lines.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Leverage-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No cost-structure snapshots logged yet."
          rowKey={(r, i) => String(r.leverage_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Business-line scorecard</h2>
        <DataTable
          rows={lineRows}
          columns={lineCols}
          emptyMessage="No business-line rollups."
          rowKey={(r, i) => String(r.business_line ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Business-line &times; leverage-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No matrix data."
          rowKey={(r, i) => `${r.business_line}-${r.leverage_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly DOL &amp; contribution trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Contribution-impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No contribution digest."
          rowKey={(r, i) => String(r.business_line ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk cost-structure queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk lines."
          rowKey={(r, i) => `${r.snapshot_code}-${i}`}
        />
      </section>
    </main>
  );
}
