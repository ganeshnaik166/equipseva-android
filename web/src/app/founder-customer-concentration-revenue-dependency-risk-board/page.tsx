import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = {
  dependency_verdict: string;
  customers: number;
  revenue_rupees: number;
  pct: number;
};
type CustRow = {
  hospital_name: string;
  revenue_lines: number;
  total_revenue_rupees: number;
  revenue_share_pct: number;
  high_churn_lines: number;
  at_risk_lines: number;
  avg_tenure_months: number;
};
type MatrixRow = {
  customer_segment: string;
  revenue_stream: string;
  customers: number;
  total_revenue_rupees: number;
  avg_share_pct: number;
};
type ExpiryRow = {
  contract_end_date: string;
  contracts: number;
  revenue_at_risk_rupees: number;
  share_at_risk_pct: number;
  high_churn_contracts: number;
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
type RegRow = {
  regulatory_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  hospital_name: string;
  customer_code: string;
  revenue_stream: string;
  trailing_12m_revenue_rupees: number;
  revenue_share_pct: number;
  concentration_bucket: string;
  contract_end_date: string | null;
  churn_risk: string;
  dependency_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    custRes,
    matrixRes,
    expiryRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3193_dependency_verdict_rollup'),
    supabase.rpc('founder_r3193_customer_scorecard'),
    supabase.rpc('founder_r3193_segment_stream_matrix'),
    supabase.rpc('founder_r3193_contract_expiry_timeline'),
    supabase.rpc('founder_r3193_capa_status_board'),
    supabase.rpc('founder_r3193_root_cause_pareto'),
    supabase.rpc('founder_r3193_regulatory_impact_digest'),
    supabase.rpc('founder_r3193_high_risk_accounts'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const custRows: CustRow[] = (custRes.data as CustRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const expiryRows: ExpiryRow[] = (expiryRes.data as ExpiryRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'dependency_verdict', header: 'Dependency Verdict' },
    { key: 'customers', header: 'Revenue Lines' },
    { key: 'revenue_rupees', header: 'T12M Revenue (INR)' },
    { key: 'pct', header: 'Revenue Share %' },
  ];

  const custCols: Column<CustRow>[] = [
    { key: 'hospital_name', header: 'Customer' },
    { key: 'revenue_lines', header: 'Lines' },
    { key: 'total_revenue_rupees', header: 'T12M Revenue (INR)' },
    { key: 'revenue_share_pct', header: 'Share %' },
    { key: 'high_churn_lines', header: 'High Churn' },
    { key: 'at_risk_lines', header: 'At Risk' },
    { key: 'avg_tenure_months', header: 'Avg Tenure (mo)' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'customer_segment', header: 'Segment' },
    { key: 'revenue_stream', header: 'Revenue Stream' },
    { key: 'customers', header: 'Lines' },
    { key: 'total_revenue_rupees', header: 'T12M Revenue (INR)' },
    { key: 'avg_share_pct', header: 'Avg Share %' },
  ];

  const expiryCols: Column<ExpiryRow>[] = [
    { key: 'contract_end_date', header: 'Contract End' },
    { key: 'contracts', header: 'Contracts' },
    { key: 'revenue_at_risk_rupees', header: 'Revenue at Risk (INR)' },
    { key: 'share_at_risk_pct', header: 'Share at Risk %' },
    { key: 'high_churn_contracts', header: 'High Churn' },
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

  const regCols: Column<RegRow>[] = [
    { key: 'regulatory_impact', header: 'Governance Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Customer' },
    { key: 'customer_code', header: 'Code' },
    { key: 'revenue_stream', header: 'Stream' },
    { key: 'trailing_12m_revenue_rupees', header: 'T12M Revenue (INR)' },
    { key: 'revenue_share_pct', header: 'Share %' },
    { key: 'concentration_bucket', header: 'Bucket' },
    { key: 'contract_end_date', header: 'Contract End' },
    { key: 'churn_risk', header: 'Churn Risk' },
    { key: 'dependency_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Concentration &amp; Revenue-Dependency Risk Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Concentration risk log — customer &times; segment &times; trailing-12m revenue &times;
        share % &times; top-N bucket &times; contract expiry &times; churn &amp; dependency verdict
        with mitigation CAPA. Founder-gated view: verdict rollups, customer scorecards,
        expiry timeline, root-cause pareto, and governance-impact digest.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Dependency verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No concentration lines logged yet."
          rowKey={(r, i) => String(r.dependency_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Customer dependency scorecard</h2>
        <DataTable
          rows={custRows}
          columns={custCols}
          emptyMessage="No customer rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Segment &times; revenue-stream matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No segment breakdown."
          rowKey={(r, i) => `${r.customer_segment}-${r.revenue_stream}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Contract expiry timeline</h2>
        <DataTable
          rows={expiryRows}
          columns={expiryCols}
          emptyMessage="No dated contracts."
          rowKey={(r, i) => String(r.contract_end_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Governance impact digest</h2>
        <DataTable
          rows={regRows}
          columns={regCols}
          emptyMessage="No governance-impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk accounts queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk accounts."
          rowKey={(r, i) => `${r.customer_code}-${i}`}
        />
      </section>
    </main>
  );
}
