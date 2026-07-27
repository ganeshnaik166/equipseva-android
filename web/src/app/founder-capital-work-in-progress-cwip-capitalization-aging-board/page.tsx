import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = {
  capitalization_status: string;
  projects: number;
  total_cwip_balance_rupees: number;
  pct: number;
};
type CategoryRow = {
  asset_category: string;
  total_projects: number;
  ready_to_capitalize: number;
  stalled: number;
  over_budget: number;
  capitalized: number;
  total_cwip_balance_rupees: number;
  avg_pct_complete: number;
};
type MatrixRow = {
  asset_category: string;
  capitalization_status: string;
  projects: number;
  total_cwip_balance_rupees: number;
  avg_aging_days: number;
};
type TrendRow = {
  cap_month: string;
  projects: number;
  total_cwip_balance_rupees: number;
  capitalized_ytd_rupees: number;
  avg_aging_days: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cost_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_rupees: number;
  pct: number;
};
type ImpactRow = {
  audit_impact: string;
  findings: number;
  open_findings: number;
  total_balance_at_risk_rupees: number;
};
type RiskRow = {
  cwip_code: string;
  project_name: string;
  asset_category: string;
  capitalization_status: string;
  cwip_balance_rupees: number;
  aging_days: number;
  pct_complete: number | null;
  expected_cap_date: string | null;
  trend_dir: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    categoryRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3501_capitalization_status_rollup'),
    supabase.rpc('founder_r3501_asset_category_scorecard'),
    supabase.rpc('founder_r3501_category_status_matrix'),
    supabase.rpc('founder_r3501_monthly_cwip_trend'),
    supabase.rpc('founder_r3501_capa_status_board'),
    supabase.rpc('founder_r3501_root_cause_pareto'),
    supabase.rpc('founder_r3501_cwip_balance_impact_digest'),
    supabase.rpc('founder_r3501_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const categoryRows: CategoryRow[] = (categoryRes.data as CategoryRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'capitalization_status', header: 'Capitalization Status' },
    { key: 'projects', header: 'Projects' },
    { key: 'total_cwip_balance_rupees', header: 'CWIP Balance (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const categoryCols: Column<CategoryRow>[] = [
    { key: 'asset_category', header: 'Asset Category' },
    { key: 'total_projects', header: 'Projects' },
    { key: 'ready_to_capitalize', header: 'Ready to Cap' },
    { key: 'stalled', header: 'Stalled' },
    { key: 'over_budget', header: 'Over Budget' },
    { key: 'capitalized', header: 'Capitalized' },
    { key: 'total_cwip_balance_rupees', header: 'CWIP Balance (INR)' },
    { key: 'avg_pct_complete', header: 'Avg % Complete' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'asset_category', header: 'Asset Category' },
    { key: 'capitalization_status', header: 'Status' },
    { key: 'projects', header: 'Projects' },
    { key: 'total_cwip_balance_rupees', header: 'CWIP Balance (INR)' },
    { key: 'avg_aging_days', header: 'Avg Aging Days' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'cap_month', header: 'Expected Cap Month' },
    { key: 'projects', header: 'Projects' },
    { key: 'total_cwip_balance_rupees', header: 'CWIP Balance (INR)' },
    { key: 'capitalized_ytd_rupees', header: 'Capitalized YTD (INR)' },
    { key: 'avg_aging_days', header: 'Avg Aging Days' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const impactCols: Column<ImpactRow>[] = [
    { key: 'audit_impact', header: 'Audit Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_balance_at_risk_rupees', header: 'CWIP at Risk (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'cwip_code', header: 'CWIP Code' },
    { key: 'project_name', header: 'Project' },
    { key: 'asset_category', header: 'Category' },
    { key: 'capitalization_status', header: 'Status' },
    { key: 'cwip_balance_rupees', header: 'CWIP Balance (INR)' },
    { key: 'aging_days', header: 'Aging Days' },
    { key: 'pct_complete', header: '% Complete' },
    { key: 'expected_cap_date', header: 'Expected Cap Date' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Capital Work-in-Progress (CWIP) Capitalization / Aging Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated CWIP register — capital projects (medical equipment, IT infrastructure, facility
        &amp; civil works, fleet, service tooling, software platforms, leasehold improvements, biomedical
        lab setups) tracked by CWIP balance &times; capitalized-YTD &times; spend-vs-budget &times; aging
        days &times; percent complete &times; capitalization status &times; expected cap date &amp; trend.
        Surfaces stuck CWIP that should be capitalized, over-budget overruns, and aged balances alongside
        CAPA closure, root-cause pareto, and an Ind AS 16 / audit-impact digest of CWIP balance at risk.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Capitalization status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No CWIP projects logged yet."
          rowKey={(r, i) => String(r.capitalization_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Asset-category scorecard</h2>
        <DataTable
          rows={categoryRows}
          columns={categoryCols}
          emptyMessage="No asset-category rollups."
          rowKey={(r, i) => String(r.asset_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Asset category &times; status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No projects by asset category."
          rowKey={(r, i) => `${r.asset_category}-${r.capitalization_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly CWIP capitalization trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.cap_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. CWIP-balance impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No audit-impact rollups."
          rowKey={(r, i) => String(r.audit_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk CWIP queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk CWIP projects."
          rowKey={(r, i) => `${r.cwip_code}-${i}`}
        />
      </section>
    </main>
  );
}
