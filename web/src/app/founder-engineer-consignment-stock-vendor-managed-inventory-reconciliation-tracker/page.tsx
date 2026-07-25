import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { recon_status: string; records: number; pct: number };
type SupplierRow = {
  supplier_name: string;
  total_records: number;
  matched: number;
  short: number;
  excess: number;
  under_investigation: number;
  discrepancy_records: number;
  total_variance_value_rupees: number;
  match_pct: number;
};
type MatrixRow = {
  stock_type: string;
  recon_status: string;
  records: number;
  total_variance_qty: number;
  total_variance_value_rupees: number;
};
type TrendRow = {
  recon_month: string;
  records: number;
  matched: number;
  discrepancies: number;
  total_variance_value_rupees: number;
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
type ImpactRow = {
  variance_impact: string;
  findings: number;
  open_findings: number;
  total_impact_rupees: number;
};
type RiskRow = {
  engineer_name: string;
  location_name: string;
  part_name: string;
  part_code: string;
  supplier_name: string;
  stock_type: string;
  recon_status: string;
  variance_qty: number;
  variance_value_rupees: number | null;
  aging_days: number | null;
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
    supabase.rpc('founder_r3440_recon_status_rollup'),
    supabase.rpc('founder_r3440_supplier_scorecard'),
    supabase.rpc('founder_r3440_stock_type_status_matrix'),
    supabase.rpc('founder_r3440_monthly_recon_trend'),
    supabase.rpc('founder_r3440_capa_status_board'),
    supabase.rpc('founder_r3440_root_cause_pareto'),
    supabase.rpc('founder_r3440_variance_value_impact_digest'),
    supabase.rpc('founder_r3440_high_risk_queue'),
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
    { key: 'recon_status', header: 'Recon Status' },
    { key: 'records', header: 'Records' },
    { key: 'pct', header: 'Share %' },
  ];

  const supplierCols: Column<SupplierRow>[] = [
    { key: 'supplier_name', header: 'Supplier' },
    { key: 'total_records', header: 'Records' },
    { key: 'matched', header: 'Matched' },
    { key: 'short', header: 'Short' },
    { key: 'excess', header: 'Excess' },
    { key: 'under_investigation', header: 'Under Investigation' },
    { key: 'discrepancy_records', header: 'Discrepancies' },
    { key: 'total_variance_value_rupees', header: 'Variance Value (INR)' },
    { key: 'match_pct', header: 'Match %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'stock_type', header: 'Stock Type' },
    { key: 'recon_status', header: 'Recon Status' },
    { key: 'records', header: 'Records' },
    { key: 'total_variance_qty', header: 'Total Variance Qty' },
    { key: 'total_variance_value_rupees', header: 'Variance Value (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'recon_month', header: 'Month' },
    { key: 'records', header: 'Records' },
    { key: 'matched', header: 'Matched' },
    { key: 'discrepancies', header: 'Discrepancies' },
    { key: 'total_variance_value_rupees', header: 'Variance Value (INR)' },
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

  const impactCols: Column<ImpactRow>[] = [
    { key: 'variance_impact', header: 'Variance Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'location_name', header: 'Location' },
    { key: 'part_name', header: 'Part' },
    { key: 'part_code', header: 'Code' },
    { key: 'supplier_name', header: 'Supplier' },
    { key: 'stock_type', header: 'Stock Type' },
    { key: 'recon_status', header: 'Status' },
    { key: 'variance_qty', header: 'Variance Qty' },
    { key: 'variance_value_rupees', header: 'Variance Value (INR)' },
    { key: 'aging_days', header: 'Aging Days' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Consignment-Stock / Vendor-Managed-Inventory (VMI) Reconciliation Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Field spare-parts consignment &amp; vendor-managed-inventory (VMI) reconciliation log — location
        &times; part &times; supplier &times; stock type (consignment, VMI, owned buffer) &times; system
        vs physical count &times; variance qty &amp; rupee value &times; recon status &times; stock aging
        &times; discrepancy flag &amp; CAPA recovery. Founder-gated view: recon-status distribution,
        supplier scorecards, root-cause pareto, and variance-value impact digest across financial-leakage
        &amp; supplier-recoverable surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Reconciliation status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No reconciliations logged yet."
          rowKey={(r, i) => String(r.recon_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Supplier reconciliation scorecard</h2>
        <DataTable
          rows={supplierRows}
          columns={supplierCols}
          emptyMessage="No supplier rollups."
          rowKey={(r, i) => String(r.supplier_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Stock type &times; recon status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No records by stock type."
          rowKey={(r, i) => `${r.stock_type}-${r.recon_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly reconciliation trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.recon_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Variance-value impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No variance-impact rollups."
          rowKey={(r, i) => String(r.variance_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk variance queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk variances."
          rowKey={(r, i) => `${r.part_code}-${i}`}
        />
      </section>
    </main>
  );
}
