import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { otd_status: string; orders: number; pct: number };
type SupplierRow = {
  supplier_name: string;
  total_orders: number;
  on_time: number;
  early: number;
  delayed: number;
  partial: number;
  otif_met_count: number;
  avg_lead_variance_days: number;
  otd_pct: number;
};
type MatrixRow = {
  supplier_name: string;
  otd_status: string;
  orders: number;
  avg_variance_days: number;
};
type TrendRow = {
  order_month: string;
  orders: number;
  on_time: number;
  delayed: number;
  partial: number;
  otif_met_count: number;
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
  otd_status: string;
  orders: number;
  total_variance_days: number;
  avg_variance_days: number;
  total_qty_short: number;
  expedited_orders: number;
};
type RiskRow = {
  supplier_name: string;
  part_name: string;
  part_code: string;
  po_number: string;
  order_date: string;
  otd_status: string;
  promised_lead_days: number;
  actual_lead_days: number;
  lead_variance_days: number;
  qty_ordered: number;
  qty_received: number;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    supplierRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3476_otd_status_rollup'),
    supabase.rpc('founder_r3476_supplier_scorecard'),
    supabase.rpc('founder_r3476_supplier_otd_matrix'),
    supabase.rpc('founder_r3476_monthly_otd_trend'),
    supabase.rpc('founder_r3476_capa_status_board'),
    supabase.rpc('founder_r3476_root_cause_pareto'),
    supabase.rpc('founder_r3476_lead_variance_impact_digest'),
    supabase.rpc('founder_r3476_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const supplierRows: SupplierRow[] = (supplierRes.data as SupplierRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'otd_status', header: 'OTD Status' },
    { key: 'orders', header: 'Orders' },
    { key: 'pct', header: 'Share %' },
  ];

  const supplierCols: Column<SupplierRow>[] = [
    { key: 'supplier_name', header: 'Supplier' },
    { key: 'total_orders', header: 'Orders' },
    { key: 'on_time', header: 'On Time' },
    { key: 'early', header: 'Early' },
    { key: 'delayed', header: 'Delayed' },
    { key: 'partial', header: 'Partial' },
    { key: 'otif_met_count', header: 'OTIF Met' },
    { key: 'avg_lead_variance_days', header: 'Avg Variance Days' },
    { key: 'otd_pct', header: 'OTD %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'supplier_name', header: 'Supplier' },
    { key: 'otd_status', header: 'OTD Status' },
    { key: 'orders', header: 'Orders' },
    { key: 'avg_variance_days', header: 'Avg Variance Days' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'order_month', header: 'Month' },
    { key: 'orders', header: 'Orders' },
    { key: 'on_time', header: 'On Time / Early' },
    { key: 'delayed', header: 'Delayed' },
    { key: 'partial', header: 'Partial' },
    { key: 'otif_met_count', header: 'OTIF Met' },
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
    { key: 'otd_status', header: 'OTD Status' },
    { key: 'orders', header: 'Orders' },
    { key: 'total_variance_days', header: 'Total Variance Days' },
    { key: 'avg_variance_days', header: 'Avg Variance Days' },
    { key: 'total_qty_short', header: 'Qty Short' },
    { key: 'expedited_orders', header: 'Expedited' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'supplier_name', header: 'Supplier' },
    { key: 'part_name', header: 'Part' },
    { key: 'part_code', header: 'Code' },
    { key: 'po_number', header: 'PO' },
    { key: 'order_date', header: 'Order Date' },
    { key: 'otd_status', header: 'OTD Status' },
    { key: 'promised_lead_days', header: 'Promised Days' },
    { key: 'actual_lead_days', header: 'Actual Days' },
    { key: 'lead_variance_days', header: 'Variance Days' },
    { key: 'qty_ordered', header: 'Qty Ord' },
    { key: 'qty_received', header: 'Qty Rec' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Spare-Part Supplier Lead-Time / On-Time-Delivery (OTD) Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Spare-part supplier lead-time &amp; OTD/OTIF performance log — supplier &times; part &times; PO
        &times; promised vs actual lead days &times; lead variance &times; qty ordered/received &times;
        OTD status (on-time, early, minor &amp; major delay, partial) &times; OTIF met &times; expedite
        flag &amp; CAPA closure. Founder-gated view: OTD distribution, supplier scorecards, root-cause
        pareto, and lead-variance impact digest across the spare-parts supply base.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. OTD status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No purchase orders logged yet."
          rowKey={(r, i) => String(r.otd_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Supplier scorecard</h2>
        <DataTable
          rows={supplierRows}
          columns={supplierCols}
          emptyMessage="No supplier rollups."
          rowKey={(r, i) => String(r.supplier_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Supplier &times; OTD status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No orders by supplier."
          rowKey={(r, i) => `${r.supplier_name}-${r.otd_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly OTD trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.order_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Lead-variance impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No lead-variance data."
          rowKey={(r, i) => String(r.otd_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk order queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk orders."
          rowKey={(r, i) => `${r.po_number}-${i}`}
        />
      </section>
    </main>
  );
}
