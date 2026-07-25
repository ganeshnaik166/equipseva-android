import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { match_verdict: string; invoices: number; pct: number };
type VendorRow = {
  vendor_name: string;
  total_invoices: number;
  clean_pay: number;
  minor_variance: number;
  hold_dispute_reject: number;
  three_way_matched_count: number;
  discrepancy_value_rupees: number;
  match_pct: number;
};
type MatrixRow = {
  spend_category: string;
  discrepancy_type: string;
  invoices: number;
  three_way_matched_count: number;
  discrepancy_value_rupees: number;
};
type TrendRow = {
  invoice_date: string;
  invoices: number;
  clean_pay: number;
  discrepancies: number;
  hold_dispute: number;
  discrepancy_value_rupees: number;
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
type ImpactRow = {
  control_impact: string;
  findings: number;
  open_findings: number;
  total_recovery_rupees: number;
};
type RiskRow = {
  vendor_name: string;
  invoice_ref: string;
  po_ref: string | null;
  grn_ref: string | null;
  spend_category: string;
  invoice_date: string;
  invoice_value_rupees: number;
  discrepancy_type: string;
  discrepancy_value_rupees: number;
  resolution_status: string;
  aging_days: number;
  match_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    vendorRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3404_match_verdict_rollup'),
    supabase.rpc('founder_r3404_vendor_scorecard'),
    supabase.rpc('founder_r3404_category_discrepancy_matrix'),
    supabase.rpc('founder_r3404_daily_match_trend'),
    supabase.rpc('founder_r3404_capa_status_board'),
    supabase.rpc('founder_r3404_root_cause_pareto'),
    supabase.rpc('founder_r3404_impact_digest'),
    supabase.rpc('founder_r3404_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const vendorRows: VendorRow[] = (vendorRes.data as VendorRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'match_verdict', header: 'Match Verdict' },
    { key: 'invoices', header: 'Invoices' },
    { key: 'pct', header: 'Share %' },
  ];

  const vendorCols: Column<VendorRow>[] = [
    { key: 'vendor_name', header: 'Vendor' },
    { key: 'total_invoices', header: 'Invoices' },
    { key: 'clean_pay', header: 'Clean Pay' },
    { key: 'minor_variance', header: 'Minor Variance' },
    { key: 'hold_dispute_reject', header: 'Hold / Dispute / Reject' },
    { key: 'three_way_matched_count', header: '3-Way Matched' },
    { key: 'discrepancy_value_rupees', header: 'Discrepancy (INR)' },
    { key: 'match_pct', header: 'Match %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'spend_category', header: 'Spend Category' },
    { key: 'discrepancy_type', header: 'Discrepancy Type' },
    { key: 'invoices', header: 'Invoices' },
    { key: 'three_way_matched_count', header: '3-Way Matched' },
    { key: 'discrepancy_value_rupees', header: 'Discrepancy (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'invoice_date', header: 'Invoice Date' },
    { key: 'invoices', header: 'Invoices' },
    { key: 'clean_pay', header: 'Clean Pay' },
    { key: 'discrepancies', header: 'Discrepancies' },
    { key: 'hold_dispute', header: 'Hold / Dispute' },
    { key: 'discrepancy_value_rupees', header: 'Discrepancy (INR)' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_recovery_rupees', header: 'Avg Recovery (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_recovery_rupees', header: 'Total Recovery (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const impactCols: Column<ImpactRow>[] = [
    { key: 'control_impact', header: 'Control Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_recovery_rupees', header: 'Total Recovery (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'vendor_name', header: 'Vendor' },
    { key: 'invoice_ref', header: 'Invoice' },
    { key: 'po_ref', header: 'PO' },
    { key: 'grn_ref', header: 'GRN' },
    { key: 'spend_category', header: 'Category' },
    { key: 'invoice_date', header: 'Date' },
    { key: 'invoice_value_rupees', header: 'Invoice (INR)' },
    { key: 'discrepancy_type', header: 'Discrepancy' },
    { key: 'discrepancy_value_rupees', header: 'Disc. Value (INR)' },
    { key: 'resolution_status', header: 'Resolution' },
    { key: 'aging_days', header: 'Aging (d)' },
    { key: 'match_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Vendor-Invoice Three-Way-Match Discrepancy Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        AP finance-integrity log — vendor &times; spend category (spare parts, logistics, IT/SaaS,
        professional services, consumables, tools) &times; three-way match (PO vs GRN vs invoice)
        &times; quantity, price &amp; GST checks &times; discrepancy type &times; discrepancy value
        &times; resolution status &times; aging &amp; CAPA control closure. Founder-gated view: match
        verdicts, vendor scorecards, category &times; discrepancy matrix, root-cause pareto, and
        control-impact digest so every invoice is cleared, corrected, disputed or rejected before AP
        payment &mdash; catching price variance, short shipments, tax mismatch, missing GRN, duplicate
        invoices &amp; no-PO spend.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Match verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No invoices matched yet."
          rowKey={(r, i) => String(r.match_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Vendor match scorecard</h2>
        <DataTable
          rows={vendorRows}
          columns={vendorCols}
          emptyMessage="No vendor rollups."
          rowKey={(r, i) => String(r.vendor_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Spend category &times; discrepancy matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No checks by spend category."
          rowKey={(r, i) => `${r.spend_category}-${r.discrepancy_type}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily three-way-match trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.invoice_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Control impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No control-impact rollups."
          rowKey={(r, i) => String(r.control_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk invoice queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk invoices."
          rowKey={(r, i) => `${r.invoice_ref}-${r.invoice_date}-${i}`}
        />
      </section>
    </main>
  );
}
