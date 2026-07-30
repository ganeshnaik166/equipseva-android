import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { budget_status: string; projects: number; total_budget_rupees: number; pct: number };
type BuRow = {
  business_unit: string;
  total_projects: number;
  on_budget: number;
  over_budget: number;
  stalled: number;
  total_budget_rupees: number;
  total_actual_rupees: number;
  avg_utilization_pct: number;
};
type MatrixRow = {
  business_unit: string;
  budget_status: string;
  projects: number;
  total_budget_rupees: number;
  avg_variance_pct: number;
};
type TrendRow = {
  period_month: string;
  projects: number;
  total_budget_rupees: number;
  total_actual_rupees: number;
  total_committed_rupees: number;
  avg_utilization_pct: number;
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
  impact_severity: string;
  findings: number;
  open_findings: number;
  total_impact_rupees: number;
};
type RiskRow = {
  project_name: string;
  project_code: string;
  business_unit: string;
  period_month: string;
  budget_status: string;
  budget_utilization_pct: number;
  variance_pct: number;
  forecast_at_completion_rupees: number;
  physical_progress_pct: number;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    buRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3603_budget_status_rollup'),
    supabase.rpc('founder_r3603_business_unit_scorecard'),
    supabase.rpc('founder_r3603_bu_status_matrix'),
    supabase.rpc('founder_r3603_monthly_capex_trend'),
    supabase.rpc('founder_r3603_capa_status_board'),
    supabase.rpc('founder_r3603_root_cause_pareto'),
    supabase.rpc('founder_r3603_variance_impact_digest'),
    supabase.rpc('founder_r3603_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const buRows: BuRow[] = (buRes.data as BuRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'budget_status', header: 'Budget Status' },
    { key: 'projects', header: 'Projects' },
    { key: 'total_budget_rupees', header: 'Total Budget (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const buCols: Column<BuRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'total_projects', header: 'Projects' },
    { key: 'on_budget', header: 'On Budget' },
    { key: 'over_budget', header: 'Over Budget' },
    { key: 'stalled', header: 'Stalled' },
    { key: 'total_budget_rupees', header: 'Total Budget (INR)' },
    { key: 'total_actual_rupees', header: 'Total Actual (INR)' },
    { key: 'avg_utilization_pct', header: 'Avg Utilization %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'budget_status', header: 'Budget Status' },
    { key: 'projects', header: 'Projects' },
    { key: 'total_budget_rupees', header: 'Total Budget (INR)' },
    { key: 'avg_variance_pct', header: 'Avg Variance %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Period' },
    { key: 'projects', header: 'Projects' },
    { key: 'total_budget_rupees', header: 'Budget (INR)' },
    { key: 'total_actual_rupees', header: 'Actual (INR)' },
    { key: 'total_committed_rupees', header: 'Committed (INR)' },
    { key: 'avg_utilization_pct', header: 'Avg Utilization %' },
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
    { key: 'impact_severity', header: 'Impact Severity' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'project_name', header: 'Project' },
    { key: 'project_code', header: 'Code' },
    { key: 'business_unit', header: 'Business Unit' },
    { key: 'period_month', header: 'Period' },
    { key: 'budget_status', header: 'Status' },
    { key: 'budget_utilization_pct', header: 'Utilization %' },
    { key: 'variance_pct', header: 'Variance %' },
    { key: 'forecast_at_completion_rupees', header: 'FAC (INR)' },
    { key: 'physical_progress_pct', header: 'Progress %' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        CAPEX Plan-vs-Actual / Capital-Budget Utilization Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated capital-budget utilization view &mdash; capex plan-vs-actual per project &times;
        business unit (projects, diagnostics, AMC services, spare parts &amp; rentals) &times; period
        &times; budget &times; actual &times; committed &times; utilization % &times; variance % &times;
        forecast-at-completion &times; physical progress &times; capitalized-to-date &amp; CAPA closure.
        Surfaces budget-status distribution, business-unit scorecards, a business-unit &times; status
        matrix, monthly capex trend, root-cause pareto, and a variance-impact digest across the CAPEX book.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Budget-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No capex projects logged yet."
          rowKey={(r, i) => String(r.budget_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Business-unit scorecard</h2>
        <DataTable
          rows={buRows}
          columns={buCols}
          emptyMessage="No business-unit rollups."
          rowKey={(r, i) => String(r.business_unit ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Business-unit &times; budget-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No projects by business unit."
          rowKey={(r, i) => `${r.business_unit}-${r.budget_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly capex trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Variance-impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No variance-impact rollups."
          rowKey={(r, i) => String(r.impact_severity ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk capex queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk projects."
          rowKey={(r, i) => `${r.project_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
