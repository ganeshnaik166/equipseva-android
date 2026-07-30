import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { income_status: string; entries: number; pct: number };
type UnitRow = {
  business_unit: string;
  entries: number;
  strong: number;
  below_budget: number;
  volatile: number;
  total_income_rupees: number;
  total_budget_rupees: number;
  avg_variance_pct: number;
};
type MatrixRow = {
  income_category: string;
  income_status: string;
  entries: number;
  total_income_rupees: number;
  avg_contribution_to_pbt_pct: number;
};
type TrendRow = {
  period_month: string;
  entries: number;
  total_income_rupees: number;
  total_budget_rupees: number;
  avg_variance_pct: number;
  below_budget: number;
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
type ImpactRow = {
  finding_category: string;
  findings: number;
  open_findings: number;
  total_impact_rupees: number;
};
type RiskRow = {
  income_source: string;
  income_ref: string;
  business_unit: string;
  income_category: string;
  period_month: string;
  income_status: string;
  variance_pct: number | null;
  recurring_pct: number | null;
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
    supabase.rpc('founder_r3621_income_status_rollup'),
    supabase.rpc('founder_r3621_business_unit_scorecard'),
    supabase.rpc('founder_r3621_category_status_matrix'),
    supabase.rpc('founder_r3621_monthly_income_trend'),
    supabase.rpc('founder_r3621_capa_status_board'),
    supabase.rpc('founder_r3621_root_cause_pareto'),
    supabase.rpc('founder_r3621_income_impact_digest'),
    supabase.rpc('founder_r3621_high_risk_queue'),
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
    { key: 'income_status', header: 'Income Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'pct', header: 'Share %' },
  ];

  const unitCols: Column<UnitRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'entries', header: 'Entries' },
    { key: 'strong', header: 'Strong' },
    { key: 'below_budget', header: 'Below Budget' },
    { key: 'volatile', header: 'Volatile' },
    { key: 'total_income_rupees', header: 'Income (INR)' },
    { key: 'total_budget_rupees', header: 'Budget (INR)' },
    { key: 'avg_variance_pct', header: 'Avg Variance %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'income_category', header: 'Category' },
    { key: 'income_status', header: 'Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_income_rupees', header: 'Income (INR)' },
    { key: 'avg_contribution_to_pbt_pct', header: 'Avg PBT Contribution %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_income_rupees', header: 'Income (INR)' },
    { key: 'total_budget_rupees', header: 'Budget (INR)' },
    { key: 'avg_variance_pct', header: 'Avg Variance %' },
    { key: 'below_budget', header: 'Below Budget' },
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

  const impactCols: Column<ImpactRow>[] = [
    { key: 'finding_category', header: 'Finding Category' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'income_source', header: 'Source' },
    { key: 'income_ref', header: 'Ref' },
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'income_category', header: 'Category' },
    { key: 'period_month', header: 'Month' },
    { key: 'income_status', header: 'Status' },
    { key: 'variance_pct', header: 'Variance %' },
    { key: 'recurring_pct', header: 'Recurring %' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Other-Income / Non-Operating-Income Analysis Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated non-operating income analysis &mdash; interest, scrap sales, forex gains,
        rental, misc &amp; provision writebacks per source &times; business unit &times; income
        category &times; income status &times; trend direction. Tracks actual vs budget, variance,
        recurring share, YTD and contribution to PBT, with a CAPA board for below-budget and volatile
        streams: status rollups, business-unit scorecards, root-cause pareto, and an income-impact
        digest across amc_services, spare_parts, projects, diagnostics, rentals &amp;
        corporate_treasury.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Income status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No income lines logged yet."
          rowKey={(r, i) => String(r.income_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Business-unit scorecard</h2>
        <DataTable
          rows={unitRows}
          columns={unitCols}
          emptyMessage="No business-unit rollups."
          rowKey={(r, i) => String(r.business_unit ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Category &times; status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No entries by category."
          rowKey={(r, i) => `${r.income_category}-${r.income_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly other-income trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Income-impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No impact rollups."
          rowKey={(r, i) => String(r.finding_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk income queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk income lines."
          rowKey={(r, i) => `${r.income_ref}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
