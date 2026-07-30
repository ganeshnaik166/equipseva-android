import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = {
  refund_status: string;
  claims: number;
  total_claim_rupees: number;
  total_pending_rupees: number;
  pct: number;
};
type ScorecardRow = {
  refund_category: string;
  claims: number;
  claimed_rupees: number;
  sanctioned_rupees: number;
  rejected_rupees: number;
  pending_rupees: number;
  interest_rupees: number;
  realization_pct: number;
};
type MatrixRow = {
  refund_category: string;
  refund_status: string;
  claims: number;
  claimed_rupees: number;
  pending_rupees: number;
};
type TrendRow = {
  period_month: string;
  claims: number;
  claimed_rupees: number;
  sanctioned_rupees: number;
  rejected_rupees: number;
  pending_rupees: number;
  interest_rupees: number;
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
  refund_category: string;
  open_claims: number;
  total_pending_rupees: number;
  total_interest_rupees: number;
  avg_days_pending: number;
};
type RiskRow = {
  refund_claim_ref: string;
  refund_category: string;
  refund_status: string;
  period_month: string;
  claim_amount_rupees: number;
  pending_amount_rupees: number;
  days_pending: number;
  trend_dir: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    scorecardRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3634_refund_status_rollup'),
    supabase.rpc('founder_r3634_refund_category_scorecard'),
    supabase.rpc('founder_r3634_category_status_matrix'),
    supabase.rpc('founder_r3634_monthly_refund_trend'),
    supabase.rpc('founder_r3634_capa_status_board'),
    supabase.rpc('founder_r3634_root_cause_pareto'),
    supabase.rpc('founder_r3634_pending_refund_digest'),
    supabase.rpc('founder_r3634_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const scorecardRows: ScorecardRow[] = (scorecardRes.data as ScorecardRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'refund_status', header: 'Refund Status' },
    { key: 'claims', header: 'Claims' },
    { key: 'total_claim_rupees', header: 'Claimed (INR)' },
    { key: 'total_pending_rupees', header: 'Pending (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const scorecardCols: Column<ScorecardRow>[] = [
    { key: 'refund_category', header: 'Category' },
    { key: 'claims', header: 'Claims' },
    { key: 'claimed_rupees', header: 'Claimed (INR)' },
    { key: 'sanctioned_rupees', header: 'Sanctioned (INR)' },
    { key: 'rejected_rupees', header: 'Rejected (INR)' },
    { key: 'pending_rupees', header: 'Pending (INR)' },
    { key: 'interest_rupees', header: 'Interest (INR)' },
    { key: 'realization_pct', header: 'Realization %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'refund_category', header: 'Category' },
    { key: 'refund_status', header: 'Status' },
    { key: 'claims', header: 'Claims' },
    { key: 'claimed_rupees', header: 'Claimed (INR)' },
    { key: 'pending_rupees', header: 'Pending (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Period' },
    { key: 'claims', header: 'Claims' },
    { key: 'claimed_rupees', header: 'Claimed (INR)' },
    { key: 'sanctioned_rupees', header: 'Sanctioned (INR)' },
    { key: 'rejected_rupees', header: 'Rejected (INR)' },
    { key: 'pending_rupees', header: 'Pending (INR)' },
    { key: 'interest_rupees', header: 'Interest (INR)' },
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
    { key: 'refund_category', header: 'Category' },
    { key: 'open_claims', header: 'Open Claims' },
    { key: 'total_pending_rupees', header: 'Pending (INR)' },
    { key: 'total_interest_rupees', header: 'Interest (INR)' },
    { key: 'avg_days_pending', header: 'Avg Days Pending' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'refund_claim_ref', header: 'Claim Ref' },
    { key: 'refund_category', header: 'Category' },
    { key: 'refund_status', header: 'Status' },
    { key: 'period_month', header: 'Period' },
    { key: 'claim_amount_rupees', header: 'Claimed (INR)' },
    { key: 'pending_amount_rupees', header: 'Pending (INR)' },
    { key: 'days_pending', header: 'Days Pending' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        GST Refund / Inverted-Duty / ITC Realization Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated GST refund claim-to-realization tracker — refund category (export IGST,
        inverted-duty, excess cash ledger, ITC accumulation &amp; deemed export) &times; refund
        status &times; claimed / sanctioned / rejected / pending amounts &times; interest on delay
        &times; days pending &amp; monthly trend, with CAPA closure across deficiency memos,
        GSTR-1 &lt;&gt; 3B mismatches, shipping-bill / EGM reconciliation and officer queries. Rollups
        cover status distribution, category scorecards, root-cause pareto and the high-risk
        (deficiency-memo &amp; rejected) queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Refund status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No refund claims logged yet."
          rowKey={(r, i) => String(r.refund_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Refund category scorecard</h2>
        <DataTable
          rows={scorecardRows}
          columns={scorecardCols}
          emptyMessage="No category rollups."
          rowKey={(r, i) => String(r.refund_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Category &times; status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No claims by category."
          rowKey={(r, i) => `${r.refund_category}-${r.refund_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly refund trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Pending-refund digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No pending refunds."
          rowKey={(r, i) => String(r.refund_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk refund queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk claims."
          rowKey={(r, i) => `${r.refund_claim_ref}-${i}`}
        />
      </section>
    </main>
  );
}
