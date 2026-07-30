import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type ReconRow = { recon_status: string; ledgers: number; pct: number };
type SegRow = {
  segment: string;
  total_ledgers: number;
  reconciled: number;
  minor_diff: number;
  material_diff: number;
  unreconciled: number;
  disputed_ledgers: number;
  total_difference_rupees: number;
  reconciled_pct: number;
};
type MatrixRow = {
  confirmation_status: string;
  recon_status: string;
  ledgers: number;
  total_difference_rupees: number;
  total_disputed_rupees: number;
};
type TrendRow = {
  period_month: string;
  ledgers: number;
  reconciled: number;
  material_diff: number;
  unreconciled: number;
  total_difference_rupees: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
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
  segment: string;
  ledgers: number;
  our_books_total_rupees: number;
  customer_statement_total_rupees: number;
  net_difference_rupees: number;
  disputed_total_rupees: number;
};
type RiskRow = {
  customer_name: string;
  account_code: string;
  segment: string;
  period_month: string;
  recon_status: string;
  confirmation_status: string;
  difference_rupees: number | null;
  disputed_rupees: number | null;
  unmatched_receipts_count: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    reconRes,
    segRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3631_recon_status_rollup'),
    supabase.rpc('founder_r3631_segment_scorecard'),
    supabase.rpc('founder_r3631_confirmation_recon_matrix'),
    supabase.rpc('founder_r3631_monthly_recon_trend'),
    supabase.rpc('founder_r3631_capa_status_board'),
    supabase.rpc('founder_r3631_root_cause_pareto'),
    supabase.rpc('founder_r3631_difference_impact_digest'),
    supabase.rpc('founder_r3631_high_risk_queue'),
  ]);

  const reconRows: ReconRow[] = (reconRes.data as ReconRow[]) ?? [];
  const segRows: SegRow[] = (segRes.data as SegRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const reconCols: Column<ReconRow>[] = [
    { key: 'recon_status', header: 'Recon Status' },
    { key: 'ledgers', header: 'Ledgers' },
    { key: 'pct', header: 'Share %' },
  ];

  const segCols: Column<SegRow>[] = [
    { key: 'segment', header: 'Segment' },
    { key: 'total_ledgers', header: 'Ledgers' },
    { key: 'reconciled', header: 'Reconciled' },
    { key: 'minor_diff', header: 'Minor Diff' },
    { key: 'material_diff', header: 'Material Diff' },
    { key: 'unreconciled', header: 'Unreconciled' },
    { key: 'disputed_ledgers', header: 'Disputed' },
    { key: 'total_difference_rupees', header: 'Total Diff (INR)' },
    { key: 'reconciled_pct', header: 'Reconciled %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'confirmation_status', header: 'Confirmation' },
    { key: 'recon_status', header: 'Recon Status' },
    { key: 'ledgers', header: 'Ledgers' },
    { key: 'total_difference_rupees', header: 'Total Diff (INR)' },
    { key: 'total_disputed_rupees', header: 'Total Disputed (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Period' },
    { key: 'ledgers', header: 'Ledgers' },
    { key: 'reconciled', header: 'Reconciled' },
    { key: 'material_diff', header: 'Material Diff' },
    { key: 'unreconciled', header: 'Unreconciled' },
    { key: 'total_difference_rupees', header: 'Total Diff (INR)' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
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
    { key: 'segment', header: 'Segment' },
    { key: 'ledgers', header: 'Ledgers' },
    { key: 'our_books_total_rupees', header: 'Our Books (INR)' },
    { key: 'customer_statement_total_rupees', header: 'Customer Statement (INR)' },
    { key: 'net_difference_rupees', header: 'Net Difference (INR)' },
    { key: 'disputed_total_rupees', header: 'Disputed (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'customer_name', header: 'Customer' },
    { key: 'account_code', header: 'Account' },
    { key: 'segment', header: 'Segment' },
    { key: 'period_month', header: 'Period' },
    { key: 'recon_status', header: 'Recon Status' },
    { key: 'confirmation_status', header: 'Confirmation' },
    { key: 'difference_rupees', header: 'Difference (INR)' },
    { key: 'disputed_rupees', header: 'Disputed (INR)' },
    { key: 'unmatched_receipts_count', header: 'Unmatched Receipts' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer-Ledger Reconciliation / Debtor-Confirmation Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated customer-ledger reconciliation &mdash; our books vs the customer statement across
        segments (AMC services, spare parts, projects, diagnostics, equipment sales &amp; consumables)
        &times; confirmation status &times; recon status &times; difference &amp; disputed rupees
        &times; unmatched receipts &times; reconciliation trend &amp; CAPA recovery closure. Surfaces
        recon-status distribution, segment scorecards, a confirmation &times; recon matrix, monthly
        trend, root-cause pareto, and a high-risk queue for material-diff &amp; unreconciled accounts.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Recon-status distribution</h2>
        <DataTable
          rows={reconRows}
          columns={reconCols}
          emptyMessage="No ledger reconciliations logged yet."
          rowKey={(r, i) => String(r.recon_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Segment reconciliation scorecard</h2>
        <DataTable
          rows={segRows}
          columns={segCols}
          emptyMessage="No segment rollups."
          rowKey={(r, i) => String(r.segment ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Confirmation &times; recon-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No matrix data."
          rowKey={(r, i) => `${r.confirmation_status}-${r.recon_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly reconciliation trend</h2>
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
          emptyMessage="No CAPA actions."
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Difference-impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No difference-impact rollups."
          rowKey={(r, i) => String(r.segment ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk debtor queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk ledgers."
          rowKey={(r, i) => `${r.account_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
