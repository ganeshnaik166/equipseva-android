import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type ApprovalRow = { approval_status: string; txns: number; pct: number };
type RelRow = {
  relationship: string;
  total_txns: number;
  board_approved: number;
  pending_txns: number;
  non_compliant: number;
  undisclosed: number;
  high_variance: number;
  total_amount_rupees: number;
  compliant_pct: number;
};
type MatrixRow = {
  transaction_type: string;
  approval_status: string;
  txns: number;
  total_amount_rupees: number;
  avg_variance_pct: number;
};
type TrendRow = {
  period_month: string;
  txns: number;
  total_amount_rupees: number;
  non_compliant: number;
  undisclosed: number;
  avg_variance_pct: number;
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
type ExposureRow = {
  disclosure_impact: string;
  findings: number;
  open_findings: number;
  total_impact_rupees: number;
};
type RiskRow = {
  related_party: string;
  txn_code: string;
  relationship: string;
  transaction_type: string;
  period_month: string;
  amount_rupees: number;
  variance_pct: number | null;
  approval_status: string;
  disclosed_flag: string;
  risk_level: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    approvalRes,
    relRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    exposureRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3513_approval_status_rollup'),
    supabase.rpc('founder_r3513_relationship_scorecard'),
    supabase.rpc('founder_r3513_txn_type_approval_matrix'),
    supabase.rpc('founder_r3513_monthly_rpt_trend'),
    supabase.rpc('founder_r3513_capa_status_board'),
    supabase.rpc('founder_r3513_root_cause_pareto'),
    supabase.rpc('founder_r3513_exposure_impact_digest'),
    supabase.rpc('founder_r3513_high_risk_queue'),
  ]);

  const approvalRows: ApprovalRow[] = (approvalRes.data as ApprovalRow[]) ?? [];
  const relRows: RelRow[] = (relRes.data as RelRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const exposureRows: ExposureRow[] = (exposureRes.data as ExposureRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const approvalCols: Column<ApprovalRow>[] = [
    { key: 'approval_status', header: 'Approval Status' },
    { key: 'txns', header: 'Transactions' },
    { key: 'pct', header: 'Share %' },
  ];

  const relCols: Column<RelRow>[] = [
    { key: 'relationship', header: 'Relationship' },
    { key: 'total_txns', header: 'Transactions' },
    { key: 'board_approved', header: 'Approved' },
    { key: 'pending_txns', header: 'Pending' },
    { key: 'non_compliant', header: 'Non-Compliant' },
    { key: 'undisclosed', header: 'Undisclosed' },
    { key: 'high_variance', header: 'High Variance' },
    { key: 'total_amount_rupees', header: 'Total Amount (INR)' },
    { key: 'compliant_pct', header: 'Compliant %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'transaction_type', header: 'Transaction Type' },
    { key: 'approval_status', header: 'Approval Status' },
    { key: 'txns', header: 'Transactions' },
    { key: 'total_amount_rupees', header: 'Total Amount (INR)' },
    { key: 'avg_variance_pct', header: 'Avg Variance %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'txns', header: 'Transactions' },
    { key: 'total_amount_rupees', header: 'Total Amount (INR)' },
    { key: 'non_compliant', header: 'Non-Compliant' },
    { key: 'undisclosed', header: 'Undisclosed' },
    { key: 'avg_variance_pct', header: 'Avg Variance %' },
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

  const exposureCols: Column<ExposureRow>[] = [
    { key: 'disclosure_impact', header: 'Disclosure Surface' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'related_party', header: 'Related Party' },
    { key: 'txn_code', header: 'Txn' },
    { key: 'relationship', header: 'Relationship' },
    { key: 'transaction_type', header: 'Type' },
    { key: 'period_month', header: 'Month' },
    { key: 'amount_rupees', header: 'Amount (INR)' },
    { key: 'variance_pct', header: 'Variance %' },
    { key: 'approval_status', header: 'Approval' },
    { key: 'disclosed_flag', header: 'Disclosure' },
    { key: 'risk_level', header: 'Risk' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Related-Party-Transaction Arms-Length / Disclosure Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated related-party transaction (RPT) governance ledger &mdash; related party &times;
        relationship (director, promoter, subsidiary, associate, KMP &amp; relatives) &times; transaction
        type (sale, purchase, loan, guarantee, lease, service, reimbursement) &times; arms-length benchmark
        &amp; variance % &times; board / audit-committee approval &amp; disclosure status &times; monthly
        RPT trend &amp; CAPA closure. Rollups surface approval distribution, relationship scorecards,
        root-cause pareto and exposure-impact across SEBI LODR &amp; board-disclosure surfaces, plus a
        high-risk queue of non-compliant, pending, undisclosed and off-benchmark deals.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Approval-status distribution</h2>
        <DataTable
          rows={approvalRows}
          columns={approvalCols}
          emptyMessage="No related-party transactions logged yet."
          rowKey={(r, i) => String(r.approval_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Relationship scorecard</h2>
        <DataTable
          rows={relRows}
          columns={relCols}
          emptyMessage="No relationship rollups."
          rowKey={(r, i) => String(r.relationship ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Transaction type &times; approval matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No transactions by type."
          rowKey={(r, i) => `${r.transaction_type}-${r.approval_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly RPT trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Exposure-impact digest</h2>
        <DataTable
          rows={exposureRows}
          columns={exposureCols}
          emptyMessage="No exposure rollups."
          rowKey={(r, i) => String(r.disclosure_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk RPT queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk transactions."
          rowKey={(r, i) => `${r.txn_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
