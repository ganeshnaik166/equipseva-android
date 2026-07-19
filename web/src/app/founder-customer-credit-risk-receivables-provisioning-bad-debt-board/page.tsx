import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = {
  account_verdict: string;
  accounts: number;
  total_outstanding_rupees: number;
  pct: number;
};
type SegRow = {
  customer_segment: string;
  total_accounts: number;
  healthy: number;
  at_risk: number;
  total_outstanding_rupees: number;
  overdue_over_90_rupees: number;
  total_provision_rupees: number;
  avg_ecl_pct: number;
};
type MatrixRow = {
  customer_segment: string;
  credit_rating: string;
  accounts: number;
  total_outstanding_rupees: number;
  avg_ecl_pct: number;
};
type TrendRow = {
  review_date: string;
  accounts: number;
  total_outstanding_rupees: number;
  overdue_over_90_rupees: number;
  total_provision_rupees: number;
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
  customer_account_code: string;
  customer_segment: string;
  credit_rating: string;
  total_outstanding_rupees: number;
  overdue_over_90_rupees: number;
  oldest_invoice_days: number;
  legal_action_status: string | null;
  account_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    segRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3361_account_verdict_rollup'),
    supabase.rpc('founder_r3361_segment_scorecard'),
    supabase.rpc('founder_r3361_segment_rating_matrix'),
    supabase.rpc('founder_r3361_review_date_trend'),
    supabase.rpc('founder_r3361_capa_status_board'),
    supabase.rpc('founder_r3361_root_cause_pareto'),
    supabase.rpc('founder_r3361_regulatory_impact_digest'),
    supabase.rpc('founder_r3361_high_risk_accounts'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const segRows: SegRow[] = (segRes.data as SegRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'account_verdict', header: 'Account Verdict' },
    { key: 'accounts', header: 'Accounts' },
    { key: 'total_outstanding_rupees', header: 'Outstanding (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const segCols: Column<SegRow>[] = [
    { key: 'customer_segment', header: 'Segment' },
    { key: 'total_accounts', header: 'Accounts' },
    { key: 'healthy', header: 'Healthy' },
    { key: 'at_risk', header: 'At-Risk' },
    { key: 'total_outstanding_rupees', header: 'Outstanding (INR)' },
    { key: 'overdue_over_90_rupees', header: 'Overdue >90 (INR)' },
    { key: 'total_provision_rupees', header: 'Provision (INR)' },
    { key: 'avg_ecl_pct', header: 'Avg ECL %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'customer_segment', header: 'Segment' },
    { key: 'credit_rating', header: 'Credit Rating' },
    { key: 'accounts', header: 'Accounts' },
    { key: 'total_outstanding_rupees', header: 'Outstanding (INR)' },
    { key: 'avg_ecl_pct', header: 'Avg ECL %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'review_date', header: 'Review Date' },
    { key: 'accounts', header: 'Accounts' },
    { key: 'total_outstanding_rupees', header: 'Outstanding (INR)' },
    { key: 'overdue_over_90_rupees', header: 'Overdue >90 (INR)' },
    { key: 'total_provision_rupees', header: 'Provision (INR)' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Exposure (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Exposure (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const regCols: Column<RegRow>[] = [
    { key: 'regulatory_impact', header: 'Regulatory Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Exposure (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Customer' },
    { key: 'customer_account_code', header: 'Account' },
    { key: 'customer_segment', header: 'Segment' },
    { key: 'credit_rating', header: 'Rating' },
    { key: 'total_outstanding_rupees', header: 'Outstanding (INR)' },
    { key: 'overdue_over_90_rupees', header: 'Overdue >90 (INR)' },
    { key: 'oldest_invoice_days', header: 'Oldest Inv (days)' },
    { key: 'legal_action_status', header: 'Legal Action' },
    { key: 'account_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Credit-Risk, Receivables-Provisioning &amp; Bad-Debt Governance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder finance view — per-customer credit limit &times; total outstanding &times; overdue
        &gt;90 days &times; credit rating &times; expected-credit-loss provision % &times; security
        held &times; legal-action status &times; account verdict &amp; CAPA closure. Rollups across
        account verdicts, segment scorecards, segment &times; rating matrix, root-cause pareto and
        regulatory-impact digest spanning Ind AS 109 &amp; RBI NPA surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Account-verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No credit-risk accounts logged yet."
          rowKey={(r, i) => String(r.account_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Customer-segment scorecard</h2>
        <DataTable
          rows={segRows}
          columns={segCols}
          emptyMessage="No segment rollups."
          rowKey={(r, i) => String(r.customer_segment ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Segment &times; credit-rating matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No accounts by segment."
          rowKey={(r, i) => `${r.customer_segment}-${r.credit_rating}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Review-date trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.review_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Regulatory impact digest</h2>
        <DataTable
          rows={regRows}
          columns={regCols}
          emptyMessage="No regulatory-impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk accounts queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk accounts."
          rowKey={(r, i) => `${r.customer_account_code}-${i}`}
        />
      </section>
    </main>
  );
}
