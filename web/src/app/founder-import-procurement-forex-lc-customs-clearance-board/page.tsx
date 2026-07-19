import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { shipment_verdict: string; shipments: number; pct: number };
type SupplierRow = {
  oem_supplier: string;
  total_shipments: number;
  cleared: number;
  lc_action: number;
  customs_query: number;
  demurrage_risk: number;
  forex_exposure: number;
  cleared_pct: number;
};
type MatrixRow = {
  origin_country: string;
  payment_mode: string;
  shipments: number;
  cleared: number;
  avg_invoice_value_usd: number;
  avg_landed_cost_inr: number;
};
type TrendRow = {
  shipment_date: string;
  shipments: number;
  cleared: number;
  lc_action: number;
  customs_query: number;
  demurrage_risk: number;
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
  oem_supplier: string;
  shipment_ref: string;
  origin_country: string;
  shipment_date: string;
  shipment_verdict: string;
  lc_status: string | null;
  cha_clearance_status: string | null;
  invoice_value_usd: number | null;
  days_in_transit: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    supplierRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3341_shipment_verdict_rollup'),
    supabase.rpc('founder_r3341_supplier_scorecard'),
    supabase.rpc('founder_r3341_origin_payment_matrix'),
    supabase.rpc('founder_r3341_daily_clearance_trend'),
    supabase.rpc('founder_r3341_capa_status_board'),
    supabase.rpc('founder_r3341_root_cause_pareto'),
    supabase.rpc('founder_r3341_financial_impact_digest'),
    supabase.rpc('founder_r3341_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const supplierRows: SupplierRow[] = (supplierRes.data as SupplierRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'shipment_verdict', header: 'Verdict' },
    { key: 'shipments', header: 'Shipments' },
    { key: 'pct', header: 'Share %' },
  ];

  const supplierCols: Column<SupplierRow>[] = [
    { key: 'oem_supplier', header: 'OEM Supplier' },
    { key: 'total_shipments', header: 'Shipments' },
    { key: 'cleared', header: 'Cleared' },
    { key: 'lc_action', header: 'LC Action' },
    { key: 'customs_query', header: 'Customs Query' },
    { key: 'demurrage_risk', header: 'Demurrage Risk' },
    { key: 'forex_exposure', header: 'Forex Exposure' },
    { key: 'cleared_pct', header: 'Cleared %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'origin_country', header: 'Origin' },
    { key: 'payment_mode', header: 'Payment Mode' },
    { key: 'shipments', header: 'Shipments' },
    { key: 'cleared', header: 'Cleared' },
    { key: 'avg_invoice_value_usd', header: 'Avg Invoice (USD)' },
    { key: 'avg_landed_cost_inr', header: 'Avg Landed (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'shipment_date', header: 'Shipment Date' },
    { key: 'shipments', header: 'Shipments' },
    { key: 'cleared', header: 'Cleared' },
    { key: 'lc_action', header: 'LC Action' },
    { key: 'customs_query', header: 'Customs Query' },
    { key: 'demurrage_risk', header: 'Demurrage Risk' },
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
    { key: 'oem_supplier', header: 'OEM Supplier' },
    { key: 'shipment_ref', header: 'Shipment' },
    { key: 'origin_country', header: 'Origin' },
    { key: 'shipment_date', header: 'Date' },
    { key: 'shipment_verdict', header: 'Verdict' },
    { key: 'lc_status', header: 'LC Status' },
    { key: 'cha_clearance_status', header: 'CHA Clearance' },
    { key: 'invoice_value_usd', header: 'Invoice (USD)' },
    { key: 'days_in_transit', header: 'Transit Days' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Import-Procurement Forex / LC / Customs-Clearance Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Trade-finance governance for EquipSeva spare &amp; equipment imports — import shipment
        &times; origin country &times; payment mode / letter-of-credit status &times; forex hedge vs
        booked rate &times; customs duty (BCD + IGST) &times; CHA clearance &amp; demurrage &times;
        landed cost INR &times; shipment verdict &amp; CAPA closure. Founder-gated view: verdict
        rollup, supplier scorecards, root-cause pareto, and forex / customs cost-risk digest.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Shipment verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No import shipments logged yet."
          rowKey={(r, i) => String(r.shipment_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Supplier trade-finance scorecard</h2>
        <DataTable
          rows={supplierRows}
          columns={supplierCols}
          emptyMessage="No supplier rollups."
          rowKey={(r, i) => String(r.oem_supplier ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Origin &times; payment-mode matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No shipments by origin / payment mode."
          rowKey={(r, i) => `${r.origin_country}-${r.payment_mode}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily clearance trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.shipment_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Financial-impact cost-risk digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No financial-impact rollups."
          rowKey={(r, i) => String(r.financial_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk shipment queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk shipments."
          rowKey={(r, i) => `${r.shipment_ref}-${r.shipment_date}-${i}`}
        />
      </section>
    </main>
  );
}
