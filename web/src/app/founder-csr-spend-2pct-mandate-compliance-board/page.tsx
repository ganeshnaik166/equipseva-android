import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = {
  compliance_status: string;
  projects: number;
  total_obligation_rupees: number;
  total_spent_rupees: number;
  pct: number;
};
type ThemeRow = {
  csr_theme: string;
  projects: number;
  total_obligation_rupees: number;
  total_spent_rupees: number;
  total_unspent_rupees: number;
  compliant: number;
  non_compliant: number;
  avg_spend_ratio_pct: number;
};
type MatrixRow = {
  csr_theme: string;
  compliance_status: string;
  projects: number;
  total_obligation_rupees: number;
  total_spent_rupees: number;
  avg_spend_ratio_pct: number;
};
type TrendRow = {
  period_month: string;
  projects: number;
  total_obligation_rupees: number;
  total_spent_rupees: number;
  total_unspent_rupees: number;
  avg_spend_ratio_pct: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  total_shortfall_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_shortfall_rupees: number;
  pct: number;
};
type DigestRow = {
  finding_category: string;
  findings: number;
  open_findings: number;
  total_shortfall_rupees: number;
};
type RiskRow = {
  project_code: string;
  project_name: string;
  csr_theme: string;
  period_month: string;
  csr_obligation_rupees: number;
  amount_spent_rupees: number;
  unspent_rupees: number;
  spend_ratio_pct: number;
  compliance_status: string;
  trend_dir: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    themeRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3626_compliance_status_rollup'),
    supabase.rpc('founder_r3626_theme_scorecard'),
    supabase.rpc('founder_r3626_theme_status_matrix'),
    supabase.rpc('founder_r3626_monthly_spend_trend'),
    supabase.rpc('founder_r3626_capa_status_board'),
    supabase.rpc('founder_r3626_root_cause_pareto'),
    supabase.rpc('founder_r3626_unspent_impact_digest'),
    supabase.rpc('founder_r3626_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const themeRows: ThemeRow[] = (themeRes.data as ThemeRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'projects', header: 'Projects' },
    { key: 'total_obligation_rupees', header: 'Obligation (INR)' },
    { key: 'total_spent_rupees', header: 'Spent (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const themeCols: Column<ThemeRow>[] = [
    { key: 'csr_theme', header: 'CSR Theme' },
    { key: 'projects', header: 'Projects' },
    { key: 'total_obligation_rupees', header: 'Obligation (INR)' },
    { key: 'total_spent_rupees', header: 'Spent (INR)' },
    { key: 'total_unspent_rupees', header: 'Unspent (INR)' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'non_compliant', header: 'At Risk' },
    { key: 'avg_spend_ratio_pct', header: 'Avg Spend %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'csr_theme', header: 'CSR Theme' },
    { key: 'compliance_status', header: 'Compliance Status' },
    { key: 'projects', header: 'Projects' },
    { key: 'total_obligation_rupees', header: 'Obligation (INR)' },
    { key: 'total_spent_rupees', header: 'Spent (INR)' },
    { key: 'avg_spend_ratio_pct', header: 'Avg Spend %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'projects', header: 'Projects' },
    { key: 'total_obligation_rupees', header: 'Obligation (INR)' },
    { key: 'total_spent_rupees', header: 'Spent (INR)' },
    { key: 'total_unspent_rupees', header: 'Unspent (INR)' },
    { key: 'avg_spend_ratio_pct', header: 'Avg Spend %' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'total_shortfall_rupees', header: 'Shortfall (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_shortfall_rupees', header: 'Shortfall (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'finding_category', header: 'Finding Category' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_shortfall_rupees', header: 'Shortfall (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'project_code', header: 'Project' },
    { key: 'project_name', header: 'Name' },
    { key: 'csr_theme', header: 'Theme' },
    { key: 'period_month', header: 'Month' },
    { key: 'csr_obligation_rupees', header: 'Obligation (INR)' },
    { key: 'amount_spent_rupees', header: 'Spent (INR)' },
    { key: 'unspent_rupees', header: 'Unspent (INR)' },
    { key: 'spend_ratio_pct', header: 'Spend %' },
    { key: 'compliance_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        CSR Spend / 2% Mandate Compliance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Companies Act sec-135 2% CSR mandate tracker &mdash; per project: obligation vs spent vs
        committed vs unspent, spend ratio, beneficiaries, admin overhead &amp; ongoing flag, rolled
        up by compliance status and CSR theme (education, healthcare, environmental sustainability,
        rural development, women empowerment, skill development, sanitation &amp; water, disaster
        relief). Founder-gated view: compliance-status distribution, theme scorecards, theme
        &times; status matrix, monthly spend trend, CAPA board, root-cause pareto, unspent-impact
        digest, and a high-risk queue for shortfall &amp; non-compliant projects where spend &lt; 50%.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Compliance-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No CSR projects logged yet."
          rowKey={(r, i) => String(r.compliance_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. CSR theme scorecard</h2>
        <DataTable
          rows={themeRows}
          columns={themeCols}
          emptyMessage="No theme rollups."
          rowKey={(r, i) => String(r.csr_theme ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. CSR theme &times; compliance-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No projects by theme."
          rowKey={(r, i) => `${r.csr_theme}-${r.compliance_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly spend trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Unspent-impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No unspent-impact rollups."
          rowKey={(r, i) => String(r.finding_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk queue</h2>
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
