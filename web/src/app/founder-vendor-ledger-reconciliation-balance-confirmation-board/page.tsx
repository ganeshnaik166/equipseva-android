import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type ReconRow = { recon_status: string; vendors: number; total_difference_rupees: number; pct: number };
type CatRow = {
  category: string;
  vendors: number;
  reconciled: number;
  minor_diff: number;
  material_unrec: number;
  our_books_rupees: number;
  vendor_statement_rupees: number;
  difference_rupees: number;
  avg_unmatched: number;
};
type MatrixRow = {
  confirmation_status: string;
  recon_status: string;
  vendors: number;
  total_difference_rupees: number;
  total_disputed_rupees: number;
};
type TrendRow = {
  period_month: string;
  vendors: number;
  reconciled: number;
  material_unrec: number;
  total_difference_rupees: number;
  total_disputed_rupees: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_recovery_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_recovery_rupees: number;
  pct: number;
};
type DigestRow = {
  impact_band: string;
  vendors: number;
  total_difference_rupees: number;
  total_disputed_rupees: number;
  unmatched_invoices: number;
};
type RiskRow = {
  vendor_name: string;
  ledger_code: string;
  category: string;
  period_month: string;
  our_books_balance_rupees: number;
  vendor_statement_balance_rupees: number | null;
  difference_rupees: number;
  disputed_rupees: number | null;
  confirmation_status: string;
  recon_status: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    reconRes,
    catRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3624_recon_status_rollup'),
    supabase.rpc('founder_r3624_category_scorecard'),
    supabase.rpc('founder_r3624_confirmation_recon_matrix'),
    supabase.rpc('founder_r3624_monthly_recon_trend'),
    supabase.rpc('founder_r3624_capa_status_board'),
    supabase.rpc('founder_r3624_root_cause_pareto'),
    supabase.rpc('founder_r3624_difference_impact_digest'),
    supabase.rpc('founder_r3624_high_risk_queue'),
  ]);

  const reconRows: ReconRow[] = (reconRes.data as ReconRow[]) ?? [];
  const catRows: CatRow[] = (catRes.data as CatRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const reconCols: Column<ReconRow>[] = [
    { key: 'recon_status', header: 'Recon Status' },
    { key: 'vendors', header: 'Vendors' },
    { key: 'total_difference_rupees', header: 'Total Difference (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const catCols: Column<CatRow>[] = [
    { key: 'category', header: 'Category' },
    { key: 'vendors', header: 'Vendors' },
    { key: 'reconciled', header: 'Reconciled' },
    { key: 'minor_diff', header: 'Minor Diff' },
    { key: 'material_unrec', header: 'Material / Unrec' },
    { key: 'our_books_rupees', header: 'Our Books (INR)' },
    { key: 'vendor_statement_rupees', header: 'Vendor Statement (INR)' },
    { key: 'difference_rupees', header: 'Difference (INR)' },
    { key: 'avg_unmatched', header: 'Avg Unmatched Inv' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'confirmation_status', header: 'Confirmation Status' },
    { key: 'recon_status', header: 'Recon Status' },
    { key: 'vendors', header: 'Vendors' },
    { key: 'total_difference_rupees', header: 'Total Difference (INR)' },
    { key: 'total_disputed_rupees', header: 'Total Disputed (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Period' },
    { key: 'vendors', header: 'Vendors' },
    { key: 'reconciled', header: 'Reconciled' },
    { key: 'material_unrec', header: 'Material / Unrec' },
    { key: 'total_difference_rupees', header: 'Total Difference (INR)' },
    { key: 'total_disputed_rupees', header: 'Total Disputed (INR)' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_recovery_rupees', header: 'Avg Recovery Impact (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_recovery_rupees', header: 'Total Recovery Impact (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'impact_band', header: 'Difference Band' },
    { key: 'vendors', header: 'Vendors' },
    { key: 'total_difference_rupees', header: 'Total Difference (INR)' },
    { key: 'total_disputed_rupees', header: 'Total Disputed (INR)' },
    { key: 'unmatched_invoices', header: 'Unmatched Invoices' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'vendor_name', header: 'Vendor' },
    { key: 'ledger_code', header: 'Ledger' },
    { key: 'category', header: 'Category' },
    { key: 'period_month', header: 'Period' },
    { key: 'our_books_balance_rupees', header: 'Our Books (INR)' },
    { key: 'vendor_statement_balance_rupees', header: 'Vendor Stmt (INR)' },
    { key: 'difference_rupees', header: 'Difference (INR)' },
    { key: 'disputed_rupees', header: 'Disputed (INR)' },
    { key: 'confirmation_status', header: 'Confirmation' },
    { key: 'recon_status', header: 'Recon' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Vendor-Ledger Reconciliation / Balance-Confirmation Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated vendor-ledger reconciliation &mdash; our books vs vendor statement per vendor
        &times; category (AMC services, spare parts, projects, diagnostics, consumables, logistics,
        subcontractor) &times; period-month &times; difference &amp; disputed rupees &times; unmatched
        invoices &times; balance-confirmation status &times; recon verdict &times; trend &amp; CAPA
        closure. Rollups cover recon-status distribution, category scorecards, confirmation &times;
        recon matrix, root-cause pareto, difference-impact bands, and a high-risk queue of
        material-diff &amp; unreconciled vendors.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Reconciliation-status distribution</h2>
        <DataTable
          rows={reconRows}
          columns={reconCols}
          emptyMessage="No vendor ledgers logged yet."
          rowKey={(r, i) => String(r.recon_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Category scorecard</h2>
        <DataTable
          rows={catRows}
          columns={catCols}
          emptyMessage="No category rollups."
          rowKey={(r, i) => String(r.category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Confirmation-status &times; recon-status matrix</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Difference-impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No difference-impact data."
          rowKey={(r, i) => String(r.impact_band ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk vendor queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk vendors."
          rowKey={(r, i) => `${r.ledger_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
