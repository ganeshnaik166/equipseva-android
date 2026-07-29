import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { coverage_status: string; periods: number; pct: number };
type UnitRow = {
  business_unit: string;
  periods: number;
  comfortable: number;
  adequate: number;
  at_risk: number;
  avg_dscr: number;
  min_dscr: number;
  avg_interest_cover: number;
  avg_headroom_rupees: number;
  below_target: number;
};
type MatrixRow = {
  business_unit: string;
  coverage_status: string;
  periods: number;
  avg_dscr: number;
  avg_headroom_rupees: number;
};
type TrendRow = {
  period_month: string;
  periods: number;
  avg_dscr: number;
  min_dscr: number;
  avg_interest_cover: number;
  avg_headroom_rupees: number;
  at_risk: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_impact_rupees: number;
  escalated_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_impact_rupees: number;
  pct: number;
};
type ImpactRow = {
  coverage_impact: string;
  findings: number;
  open_findings: number;
  total_impact_rupees: number;
};
type RiskRow = {
  business_unit: string;
  board_ref: string;
  period_month: string;
  dscr_ratio: number;
  target_dscr: number;
  interest_cover_ratio: number;
  cash_headroom_rupees: number;
  coverage_status: string;
  trend_dir: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    unitRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3589_coverage_status_rollup'),
    supabase.rpc('founder_r3589_business_unit_scorecard'),
    supabase.rpc('founder_r3589_unit_coverage_matrix'),
    supabase.rpc('founder_r3589_monthly_dscr_trend'),
    supabase.rpc('founder_r3589_capa_status_board'),
    supabase.rpc('founder_r3589_root_cause_pareto'),
    supabase.rpc('founder_r3589_coverage_impact_digest'),
    supabase.rpc('founder_r3589_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const unitRows: UnitRow[] = (unitRes.data as UnitRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'coverage_status', header: 'Coverage Status' },
    { key: 'periods', header: 'Periods' },
    { key: 'pct', header: 'Share %' },
  ];

  const unitCols: Column<UnitRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'periods', header: 'Periods' },
    { key: 'comfortable', header: 'Comfortable' },
    { key: 'adequate', header: 'Adequate' },
    { key: 'at_risk', header: 'At Risk' },
    { key: 'avg_dscr', header: 'Avg DSCR' },
    { key: 'min_dscr', header: 'Min DSCR' },
    { key: 'avg_interest_cover', header: 'Avg Int Cover' },
    { key: 'avg_headroom_rupees', header: 'Avg Headroom (INR)' },
    { key: 'below_target', header: 'Below Target' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'coverage_status', header: 'Coverage Status' },
    { key: 'periods', header: 'Periods' },
    { key: 'avg_dscr', header: 'Avg DSCR' },
    { key: 'avg_headroom_rupees', header: 'Avg Headroom (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'periods', header: 'Periods' },
    { key: 'avg_dscr', header: 'Avg DSCR' },
    { key: 'min_dscr', header: 'Min DSCR' },
    { key: 'avg_interest_cover', header: 'Avg Int Cover' },
    { key: 'avg_headroom_rupees', header: 'Avg Headroom (INR)' },
    { key: 'at_risk', header: 'At Risk' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_impact_rupees', header: 'Avg Impact (INR)' },
    { key: 'escalated_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const impactCols: Column<ImpactRow>[] = [
    { key: 'coverage_impact', header: 'Coverage Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'board_ref', header: 'Board Ref' },
    { key: 'period_month', header: 'Month' },
    { key: 'dscr_ratio', header: 'DSCR' },
    { key: 'target_dscr', header: 'Target' },
    { key: 'interest_cover_ratio', header: 'Int Cover' },
    { key: 'cash_headroom_rupees', header: 'Headroom (INR)' },
    { key: 'coverage_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Debt-Service-Coverage (DSCR) / Interest-Cover / Liquidity Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder debt-service-coverage board — business unit &times; period &times; EBITDA &times;
        interest expense &times; principal due &times; debt service &times; DSCR ratio vs target
        &times; interest-cover ratio &times; cash headroom &times; coverage status &times; trend
        &amp; CAPA closure. Founder-gated view: coverage-status distribution, business-unit
        scorecards, monthly DSCR trend, root-cause pareto, and coverage-impact digest across
        lender-covenant &amp; board-escalation surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Coverage-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No coverage periods logged yet."
          rowKey={(r, i) => String(r.coverage_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Business-unit DSCR scorecard</h2>
        <DataTable
          rows={unitRows}
          columns={unitCols}
          emptyMessage="No business-unit rollups."
          rowKey={(r, i) => String(r.business_unit ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Business-unit &times; coverage-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No periods by business unit."
          rowKey={(r, i) => `${r.business_unit}-${r.coverage_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly DSCR trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Coverage-impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No coverage-impact rollups."
          rowKey={(r, i) => String(r.coverage_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk (breach / tight) queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk periods."
          rowKey={(r, i) => `${r.board_ref}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
