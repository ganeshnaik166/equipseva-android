import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { processing_status: string; records: number; pct: number };
type VendorRow = {
  vendor_name: string;
  records: number;
  invoices_processed_total: number;
  duplicate_flagged_total: number;
  match_exceptions_total: number;
  avg_processing_days: number | null;
  duplicate_at_risk_rupees: number | null;
  duplicate_recovered_rupees: number | null;
};
type MatrixRow = {
  invoice_class: string;
  processing_status: string;
  records: number;
  avg_processing_days: number | null;
};
type TrendRow = {
  period_month: string;
  records: number;
  duplicate_flagged_total: number;
  match_exceptions_total: number;
  avg_processing_days: number | null;
  worsening_records: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string | null;
  occurrences: number;
  pct: number;
};
type DigestRow = {
  vendor_name: string;
  records: number;
  duplicate_flagged_total: number;
  duplicate_at_risk_rupees: number | null;
  duplicate_recovered_rupees: number | null;
  unrecovered_records: number;
  fraud_suspected_records: number;
};
type RiskRow = {
  vendor_name: string;
  invoice_category: string;
  invoice_class: string;
  period_month: string;
  processing_status: string;
  duplicate_payments_at_risk_rupees: number | null;
  three_way_match_exceptions: number | null;
  avg_processing_days: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    vendorRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3744_processing_status_rollup'),
    supabase.rpc('founder_r3744_vendor_scorecard'),
    supabase.rpc('founder_r3744_invoice_class_status_matrix'),
    supabase.rpc('founder_r3744_monthly_exception_trend'),
    supabase.rpc('founder_r3744_capa_status_board'),
    supabase.rpc('founder_r3744_root_cause_pareto'),
    supabase.rpc('founder_r3744_duplicate_payment_digest'),
    supabase.rpc('founder_r3744_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const vendorRows: VendorRow[] = (vendorRes.data as VendorRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'processing_status', header: 'Processing Status' },
    { key: 'records', header: 'Records' },
    { key: 'pct', header: 'Share %' },
  ];

  const vendorCols: Column<VendorRow>[] = [
    { key: 'vendor_name', header: 'Vendor' },
    { key: 'records', header: 'Records' },
    { key: 'invoices_processed_total', header: 'Invoices Processed' },
    { key: 'duplicate_flagged_total', header: 'Duplicates Flagged' },
    { key: 'match_exceptions_total', header: '3-Way-Match Exceptions' },
    { key: 'avg_processing_days', header: 'Avg Processing Days' },
    { key: 'duplicate_at_risk_rupees', header: 'Duplicate At-Risk (Rs)' },
    { key: 'duplicate_recovered_rupees', header: 'Duplicate Recovered (Rs)' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'invoice_class', header: 'Invoice Class' },
    { key: 'processing_status', header: 'Processing Status' },
    { key: 'records', header: 'Records' },
    { key: 'avg_processing_days', header: 'Avg Processing Days' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'records', header: 'Records' },
    { key: 'duplicate_flagged_total', header: 'Duplicates Flagged' },
    { key: 'match_exceptions_total', header: '3-Way-Match Exceptions' },
    { key: 'avg_processing_days', header: 'Avg Processing Days' },
    { key: 'worsening_records', header: 'Worsening' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'overdue_flag', header: 'Overdue' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'vendor_name', header: 'Vendor' },
    { key: 'records', header: 'Records' },
    { key: 'duplicate_flagged_total', header: 'Duplicates Flagged' },
    { key: 'duplicate_at_risk_rupees', header: 'Duplicate At-Risk (Rs)' },
    { key: 'duplicate_recovered_rupees', header: 'Duplicate Recovered (Rs)' },
    { key: 'unrecovered_records', header: 'Unrecovered' },
    { key: 'fraud_suspected_records', header: 'Fraud Suspected' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'vendor_name', header: 'Vendor' },
    { key: 'invoice_category', header: 'Category' },
    { key: 'invoice_class', header: 'Invoice Class' },
    { key: 'period_month', header: 'Month' },
    { key: 'processing_status', header: 'Processing Status' },
    { key: 'duplicate_payments_at_risk_rupees', header: 'Duplicate At-Risk (Rs)' },
    { key: 'three_way_match_exceptions', header: '3-Way-Match Exceptions' },
    { key: 'avg_processing_days', header: 'Avg Processing Days' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Vendor Invoice-Processing / Duplicate-Payment Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Accounts-payable invoice-processing accuracy log — duplicate-invoice detection,
        3-way-match exceptions, processing turnaround time &amp; duplicate-payment recovery
        &times; vendor &times; invoice class &times; period month &amp; CAPA closure. Distinct
        from any credit-note/debit-note billing-adjustment-reconciliation page, which is
        CUSTOMER-side billing, and from any P2P-cycle-time page, which is the requisition-to-GRN
        cycle not invoice-payment accuracy. Founder-gated view: processing-status distribution,
        vendor scorecards, invoice-class &times; status matrix, monthly exception trend, CAPA
        status board, root-cause pareto, a duplicate-payment digest, and a high-risk queue of
        duplicate-paid-unrecovered &amp; fraud-suspected invoices.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Processing-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No invoice rows logged yet."
          rowKey={(r, i) => String(r.processing_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Vendor scorecard</h2>
        <DataTable
          rows={vendorRows}
          columns={vendorCols}
          emptyMessage="No vendor rollups."
          rowKey={(r, i) => String(r.vendor_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Invoice class &times; processing-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No invoices by class."
          rowKey={(r, i) => `${r.invoice_class}-${r.processing_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly exception trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Duplicate-payment digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No duplicate-payment risk found."
          rowKey={(r, i) => String(r.vendor_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk invoice queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk invoices."
          rowKey={(r, i) => `${r.vendor_name}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
