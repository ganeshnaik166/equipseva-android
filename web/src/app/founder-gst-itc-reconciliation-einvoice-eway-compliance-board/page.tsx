import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { compliance_verdict: string; entries: number; pct: number };
type VendorRow = {
  gstin_or_vendor: string;
  entries: number;
  total_invoices: number;
  matched_itc_rupees: number;
  unmatched_itc_rupees: number;
  itc_at_risk_rupees: number;
  avg_irn_coverage_pct: number;
  avg_eway_coverage_pct: number;
};
type MatrixRow = {
  area: string;
  mismatch_reason: string;
  entries: number;
  itc_at_risk_rupees: number;
  avg_irn_coverage_pct: number;
};
type TrendRow = {
  period_month: string;
  entries: number;
  total_invoices: number;
  matched_itc_rupees: number;
  itc_at_risk_rupees: number;
  notices: number;
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
  period_month: string;
  area: string;
  gstin_or_vendor: string;
  invoice_count: number;
  itc_at_risk_rupees: number | null;
  mismatch_reason: string;
  filing_status: string;
  compliance_verdict: string;
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
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3321_compliance_verdict_rollup'),
    supabase.rpc('founder_r3321_vendor_scorecard'),
    supabase.rpc('founder_r3321_area_reason_matrix'),
    supabase.rpc('founder_r3321_period_trend'),
    supabase.rpc('founder_r3321_capa_status_board'),
    supabase.rpc('founder_r3321_root_cause_pareto'),
    supabase.rpc('founder_r3321_regulatory_impact_digest'),
    supabase.rpc('founder_r3321_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const vendorRows: VendorRow[] = (vendorRes.data as VendorRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'compliance_verdict', header: 'Verdict' },
    { key: 'entries', header: 'Rows' },
    { key: 'pct', header: 'Share %' },
  ];

  const vendorCols: Column<VendorRow>[] = [
    { key: 'gstin_or_vendor', header: 'GSTIN / Vendor' },
    { key: 'entries', header: 'Rows' },
    { key: 'total_invoices', header: 'Invoices' },
    { key: 'matched_itc_rupees', header: 'Matched ITC (INR)' },
    { key: 'unmatched_itc_rupees', header: 'Unmatched ITC (INR)' },
    { key: 'itc_at_risk_rupees', header: 'ITC At Risk (INR)' },
    { key: 'avg_irn_coverage_pct', header: 'Avg IRN %' },
    { key: 'avg_eway_coverage_pct', header: 'Avg E-Way %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'area', header: 'Area' },
    { key: 'mismatch_reason', header: 'Mismatch Reason' },
    { key: 'entries', header: 'Rows' },
    { key: 'itc_at_risk_rupees', header: 'ITC At Risk (INR)' },
    { key: 'avg_irn_coverage_pct', header: 'Avg IRN %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Period' },
    { key: 'entries', header: 'Rows' },
    { key: 'total_invoices', header: 'Invoices' },
    { key: 'matched_itc_rupees', header: 'Matched ITC (INR)' },
    { key: 'itc_at_risk_rupees', header: 'ITC At Risk (INR)' },
    { key: 'notices', header: 'Notices' },
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
    { key: 'regulatory_impact', header: 'Regulatory Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'period_month', header: 'Period' },
    { key: 'area', header: 'Area' },
    { key: 'gstin_or_vendor', header: 'GSTIN / Vendor' },
    { key: 'invoice_count', header: 'Invoices' },
    { key: 'itc_at_risk_rupees', header: 'ITC At Risk (INR)' },
    { key: 'mismatch_reason', header: 'Mismatch Reason' },
    { key: 'filing_status', header: 'Filing Status' },
    { key: 'compliance_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder GST ITC-Reconciliation &amp; E-Invoice / E-Way-Bill Compliance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        GST tax-compliance board — area &times; GSTIN/vendor &times; GSTR-2B vs purchase-register ITC
        matched/unmatched/at-risk &times; e-invoice IRN coverage &times; e-way-bill coverage &times;
        mismatch reason &times; filing status &times; compliance verdict &amp; CAPA recovery. Founder-gated
        view: verdict rollup, vendor ITC scorecards, area &times; reason matrix, period trend, root-cause
        pareto, and regulatory-impact digest across GST notice &amp; ITC-reversal exposure.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Compliance verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No compliance rows logged yet."
          rowKey={(r, i) => String(r.compliance_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Vendor / GSTIN ITC scorecard</h2>
        <DataTable
          rows={vendorRows}
          columns={vendorCols}
          emptyMessage="No vendor rollups."
          rowKey={(r, i) => String(r.gstin_or_vendor ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Area &times; mismatch-reason matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No rows by area."
          rowKey={(r, i) => `${r.area}-${r.mismatch_reason}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Period-month trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Regulatory impact digest</h2>
        <DataTable
          rows={regRows}
          columns={regCols}
          emptyMessage="No regulatory-impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk ITC / filing queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk rows."
          rowKey={(r, i) => `${r.gstin_or_vendor}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
