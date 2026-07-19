import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { recon_verdict: string; transfers: number; pct: number };
type BranchRow = {
  from_branch: string;
  total_transfers: number;
  reconciled: number;
  mismatch: number;
  disputed: number;
  gst_noncompliant: number;
  goods_pending: number;
  total_gap_rupees: number;
  reconciled_pct: number;
};
type MatrixRow = {
  from_branch: string;
  to_branch: string;
  transfers: number;
  reconciled: number;
  avg_value_rupees: number;
  total_gap_rupees: number;
};
type TrendRow = {
  transfer_date: string;
  transfers: number;
  reconciled: number;
  mismatch: number;
  total_value_rupees: number;
  total_gap_rupees: number;
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
  financial_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  from_branch: string;
  to_branch: string;
  transfer_type: string;
  reference_no: string;
  transfer_date: string;
  settlement_status: string;
  recon_verdict: string;
  reconciliation_gap_rupees: number;
  aging_days: number;
  mismatch_reason: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    branchRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3373_recon_verdict_rollup'),
    supabase.rpc('founder_r3373_branch_scorecard'),
    supabase.rpc('founder_r3373_branch_flow_matrix'),
    supabase.rpc('founder_r3373_daily_transfer_trend'),
    supabase.rpc('founder_r3373_capa_status_board'),
    supabase.rpc('founder_r3373_root_cause_pareto'),
    supabase.rpc('founder_r3373_financial_impact_digest'),
    supabase.rpc('founder_r3373_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const branchRows: BranchRow[] = (branchRes.data as BranchRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'recon_verdict', header: 'Recon Verdict' },
    { key: 'transfers', header: 'Transfers' },
    { key: 'pct', header: 'Share %' },
  ];

  const branchCols: Column<BranchRow>[] = [
    { key: 'from_branch', header: 'From Branch' },
    { key: 'total_transfers', header: 'Transfers' },
    { key: 'reconciled', header: 'Reconciled' },
    { key: 'mismatch', header: 'Mismatch' },
    { key: 'disputed', header: 'Disputed' },
    { key: 'gst_noncompliant', header: 'GST Non-Compliant' },
    { key: 'goods_pending', header: 'Goods Pending' },
    { key: 'total_gap_rupees', header: 'Total Gap (INR)' },
    { key: 'reconciled_pct', header: 'Reconciled %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'from_branch', header: 'From Branch' },
    { key: 'to_branch', header: 'To Branch' },
    { key: 'transfers', header: 'Transfers' },
    { key: 'reconciled', header: 'Reconciled' },
    { key: 'avg_value_rupees', header: 'Avg Value (INR)' },
    { key: 'total_gap_rupees', header: 'Total Gap (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'transfer_date', header: 'Date' },
    { key: 'transfers', header: 'Transfers' },
    { key: 'reconciled', header: 'Reconciled' },
    { key: 'mismatch', header: 'Mismatch / Disputed' },
    { key: 'total_value_rupees', header: 'Total Value (INR)' },
    { key: 'total_gap_rupees', header: 'Total Gap (INR)' },
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
    { key: 'financial_impact', header: 'Financial Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'from_branch', header: 'From' },
    { key: 'to_branch', header: 'To' },
    { key: 'transfer_type', header: 'Type' },
    { key: 'reference_no', header: 'Reference' },
    { key: 'transfer_date', header: 'Date' },
    { key: 'settlement_status', header: 'Settlement' },
    { key: 'recon_verdict', header: 'Verdict' },
    { key: 'reconciliation_gap_rupees', header: 'Gap (INR)' },
    { key: 'aging_days', header: 'Aging Days' },
    { key: 'mismatch_reason', header: 'Mismatch Reason' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Inter-Company / Inter-Branch Transfer &amp; Fund-Settlement Reconciliation Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Inter-branch transfer ledger — from-branch &times; to-branch &times; transfer type &times;
        transfer value &times; GST stock-transfer compliance &times; goods-received confirmation
        &times; invoice match &times; settlement status &times; reconciliation gap &times; aging
        &times; mismatch reason &amp; CAPA closure. Founder-gated view: recon verdicts, branch
        scorecards, branch-flow matrix, root-cause pareto, and financial-impact digest across
        EquipSeva regional hubs &amp; head office.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Reconciliation verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No transfers logged yet."
          rowKey={(r, i) => String(r.recon_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Branch reconciliation scorecard</h2>
        <DataTable
          rows={branchRows}
          columns={branchCols}
          emptyMessage="No branch rollups."
          rowKey={(r, i) => String(r.from_branch ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. From-branch &times; to-branch flow matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No transfers by branch pair."
          rowKey={(r, i) => `${r.from_branch}-${r.to_branch}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily transfer trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.transfer_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Financial impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No financial-impact rollups."
          rowKey={(r, i) => String(r.financial_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk reconciliation queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk transfers."
          rowKey={(r, i) => `${r.reference_no}-${r.transfer_date}-${i}`}
        />
      </section>
    </main>
  );
}
