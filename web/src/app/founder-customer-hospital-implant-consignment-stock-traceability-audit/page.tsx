import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { stock_verdict: string; skus: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_skus: number;
  healthy: number;
  reorder_now: number;
  expiry_or_expired: number;
  reconciliation_gap: number;
  below_par: number;
  unreconciled: number;
  healthy_pct: number;
};
type MatrixRow = {
  implant_category: string;
  consignment_owner: string;
  skus: number;
  healthy: number;
  avg_days_to_expiry: number;
  total_expired_qty: number;
};
type TrendRow = {
  audit_date: string;
  skus: number;
  healthy: number;
  reorder_now: number;
  expiry_risk: number;
  reconciliation_gap: number;
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
  store_location: string;
  sku_code: string;
  implant_category: string;
  consignment_owner: string;
  on_hand_qty: number;
  par_level: number;
  days_to_expiry: number;
  stock_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3295_stock_verdict_rollup'),
    supabase.rpc('founder_r3295_hospital_scorecard'),
    supabase.rpc('founder_r3295_category_owner_matrix'),
    supabase.rpc('founder_r3295_daily_audit_trend'),
    supabase.rpc('founder_r3295_capa_status_board'),
    supabase.rpc('founder_r3295_root_cause_pareto'),
    supabase.rpc('founder_r3295_regulatory_impact_digest'),
    supabase.rpc('founder_r3295_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'stock_verdict', header: 'Verdict' },
    { key: 'skus', header: 'SKUs' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_skus', header: 'SKUs' },
    { key: 'healthy', header: 'Healthy' },
    { key: 'reorder_now', header: 'Reorder Now' },
    { key: 'expiry_or_expired', header: 'Expiry / Expired' },
    { key: 'reconciliation_gap', header: 'Recon Gap' },
    { key: 'below_par', header: 'Below Par' },
    { key: 'unreconciled', header: 'Unreconciled' },
    { key: 'healthy_pct', header: 'Healthy %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'implant_category', header: 'Implant Category' },
    { key: 'consignment_owner', header: 'Consignment Owner' },
    { key: 'skus', header: 'SKUs' },
    { key: 'healthy', header: 'Healthy' },
    { key: 'avg_days_to_expiry', header: 'Avg Days to Expiry' },
    { key: 'total_expired_qty', header: 'Expired / Short-Dated Qty' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'audit_date', header: 'Date' },
    { key: 'skus', header: 'SKUs' },
    { key: 'healthy', header: 'Healthy' },
    { key: 'reorder_now', header: 'Reorder Now' },
    { key: 'expiry_risk', header: 'Expiry Risk' },
    { key: 'reconciliation_gap', header: 'Recon Gap' },
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
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'store_location', header: 'Store' },
    { key: 'sku_code', header: 'SKU' },
    { key: 'implant_category', header: 'Category' },
    { key: 'consignment_owner', header: 'Owner' },
    { key: 'on_hand_qty', header: 'On-Hand' },
    { key: 'par_level', header: 'Par' },
    { key: 'days_to_expiry', header: 'Days to Expiry' },
    { key: 'stock_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital High-Value Implant &amp; Consignment-Stock Traceability &amp; Par-Level Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Implant stock traceability log — implant category &times; consignment owner &times; on-hand
        vs par level &times; UDI barcode presence &times; expiry / short-dated units &times;
        implant-log reconciliation &times; stock verdict &amp; CAPA closure. Founder-gated view:
        stock verdicts, hospital scorecards, root-cause pareto, and regulatory-impact digest across
        NABH &amp; CDSCO surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Stock verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No stock audits logged yet."
          rowKey={(r, i) => String(r.stock_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital stock scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Implant category &times; consignment-owner matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No stock by category."
          rowKey={(r, i) => `${r.implant_category}-${r.consignment_owner}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily audit trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.audit_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk stock queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk stock."
          rowKey={(r, i) => `${r.sku_code}-${r.hospital_name}-${i}`}
        />
      </section>
    </main>
  );
}
