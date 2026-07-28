import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { claim_status: string; claims: number; pct: number };
type CategoryRow = {
  rnd_category: string;
  total_claims: number;
  approved: number;
  filed: number;
  queried: number;
  disallowed: number;
  pending: number;
  total_eligible_spend_rupees: number;
  total_deduction_claimed_rupees: number;
  total_tax_benefit_rupees: number;
  approval_pct: number;
};
type MatrixRow = {
  rnd_category: string;
  claim_status: string;
  claims: number;
  total_eligible_spend_rupees: number;
  total_tax_benefit_rupees: number;
};
type TrendRow = {
  period_month: string;
  claims: number;
  approved: number;
  disallowed: number;
  queried: number;
  total_tax_benefit_rupees: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_recovered_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_recovered_rupees: number;
  pct: number;
};
type DigestRow = {
  documentation_status: string;
  claims: number;
  total_eligible_spend_rupees: number;
  total_deduction_claimed_rupees: number;
  total_tax_benefit_rupees: number;
  avg_weighted_deduction_pct: number;
};
type RiskRow = {
  entity_name: string;
  claim_code: string;
  project_name: string;
  rnd_category: string;
  period_month: string;
  claim_status: string;
  documentation_status: string;
  eligible_spend_rupees: number;
  tax_benefit_rupees: number;
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
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3549_claim_status_rollup'),
    supabase.rpc('founder_r3549_category_scorecard'),
    supabase.rpc('founder_r3549_category_status_matrix'),
    supabase.rpc('founder_r3549_monthly_claim_trend'),
    supabase.rpc('founder_r3549_capa_status_board'),
    supabase.rpc('founder_r3549_root_cause_pareto'),
    supabase.rpc('founder_r3549_tax_benefit_impact_digest'),
    supabase.rpc('founder_r3549_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const categoryRows: CategoryRow[] = (categoryRes.data as CategoryRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'claim_status', header: 'Claim Status' },
    { key: 'claims', header: 'Claims' },
    { key: 'pct', header: 'Share %' },
  ];

  const categoryCols: Column<CategoryRow>[] = [
    { key: 'rnd_category', header: 'R&D Category' },
    { key: 'total_claims', header: 'Claims' },
    { key: 'approved', header: 'Approved' },
    { key: 'filed', header: 'Filed' },
    { key: 'queried', header: 'Queried' },
    { key: 'disallowed', header: 'Disallowed' },
    { key: 'pending', header: 'Pending' },
    { key: 'total_eligible_spend_rupees', header: 'Eligible Spend (INR)' },
    { key: 'total_deduction_claimed_rupees', header: 'Deduction Claimed (INR)' },
    { key: 'total_tax_benefit_rupees', header: 'Tax Benefit (INR)' },
    { key: 'approval_pct', header: 'Approval %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'rnd_category', header: 'R&D Category' },
    { key: 'claim_status', header: 'Claim Status' },
    { key: 'claims', header: 'Claims' },
    { key: 'total_eligible_spend_rupees', header: 'Eligible Spend (INR)' },
    { key: 'total_tax_benefit_rupees', header: 'Tax Benefit (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'claims', header: 'Claims' },
    { key: 'approved', header: 'Approved' },
    { key: 'disallowed', header: 'Disallowed' },
    { key: 'queried', header: 'Queried' },
    { key: 'total_tax_benefit_rupees', header: 'Tax Benefit (INR)' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_recovered_rupees', header: 'Avg Recovered (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_recovered_rupees', header: 'Total Recovered (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'documentation_status', header: 'Documentation Status' },
    { key: 'claims', header: 'Claims' },
    { key: 'total_eligible_spend_rupees', header: 'Eligible Spend (INR)' },
    { key: 'total_deduction_claimed_rupees', header: 'Deduction Claimed (INR)' },
    { key: 'total_tax_benefit_rupees', header: 'Tax Benefit (INR)' },
    { key: 'avg_weighted_deduction_pct', header: 'Avg Weighted Deduction %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'entity_name', header: 'Entity' },
    { key: 'claim_code', header: 'Claim' },
    { key: 'project_name', header: 'Project' },
    { key: 'rnd_category', header: 'Category' },
    { key: 'period_month', header: 'Month' },
    { key: 'claim_status', header: 'Claim Status' },
    { key: 'documentation_status', header: 'Docs' },
    { key: 'eligible_spend_rupees', header: 'Eligible Spend (INR)' },
    { key: 'tax_benefit_rupees', header: 'Tax Benefit (INR)' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        R&amp;D Tax-Credit / Weighted-Deduction Incentive Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated R&amp;D tax-credit &amp; weighted-deduction incentive tracker — project &times;
        category (product dev, process improvement, software, clinical validation, prototype) &times;
        eligible spend &times; weighted deduction % &times; deduction claimed &times; tax benefit
        &times; documentation status &times; claim status (filed, approved, queried, disallowed,
        pending) &times; monthly trend &amp; CAPA closure. Surfaces claim-status distribution, category
        scorecards, root-cause pareto, and a tax-benefit-at-risk digest across DSIR &amp; income-tax
        surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Claim status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No claims logged yet."
          rowKey={(r, i) => String(r.claim_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. R&amp;D category scorecard</h2>
        <DataTable
          rows={categoryRows}
          columns={categoryCols}
          emptyMessage="No category rollups."
          rowKey={(r, i) => String(r.rnd_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. R&amp;D category &times; claim status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No claims by category."
          rowKey={(r, i) => `${r.rnd_category}-${r.claim_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly claim trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Tax-benefit impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No documentation-status rollups."
          rowKey={(r, i) => String(r.documentation_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk claim queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk claims."
          rowKey={(r, i) => `${r.claim_code}-${i}`}
        />
      </section>
    </main>
  );
}
