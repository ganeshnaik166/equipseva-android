import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { spend_status: string; records: number; pct: number };
type SupplierRow = {
  supplier_name: string;
  records: number;
  optimized: number;
  on_target: number;
  elevated: number;
  wasteful_or_damage: number;
  total_spend_rupees: number;
  avg_cost_per_shipment: number;
  avg_variance_pct: number;
};
type MatrixRow = {
  pack_category: string;
  spend_status: string;
  records: number;
  total_spend_rupees: number;
  avg_variance_pct: number;
};
type TrendRow = {
  period_month: string;
  records: number;
  shipments: number;
  total_spend_rupees: number;
  avg_cost_per_shipment: number;
  damage_incidents: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  avg_savings_potential_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_savings_potential_rupees: number;
  pct: number;
};
type VarianceRow = {
  packaging_type: string;
  records: number;
  avg_variance_pct: number;
  max_variance_pct: number;
  total_spend_rupees: number;
  excess_spend_rupees: number;
};
type RiskRow = {
  pack_code: string;
  packaging_type: string;
  supplier_name: string;
  pack_category: string;
  period_month: string;
  spend_status: string;
  variance_pct: number | null;
  damage_incidents_linked: number | null;
  trend_dir: string | null;
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
    varianceRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3667_spend_status_rollup'),
    supabase.rpc('founder_r3667_supplier_scorecard'),
    supabase.rpc('founder_r3667_category_status_matrix'),
    supabase.rpc('founder_r3667_monthly_spend_trend'),
    supabase.rpc('founder_r3667_capa_status_board'),
    supabase.rpc('founder_r3667_root_cause_pareto'),
    supabase.rpc('founder_r3667_cost_variance_digest'),
    supabase.rpc('founder_r3667_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const supplierRows: SupplierRow[] = (supplierRes.data as SupplierRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const varianceRows: VarianceRow[] = (varianceRes.data as VarianceRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'spend_status', header: 'Spend Status' },
    { key: 'records', header: 'Records' },
    { key: 'pct', header: 'Share %' },
  ];

  const supplierCols: Column<SupplierRow>[] = [
    { key: 'supplier_name', header: 'Supplier' },
    { key: 'records', header: 'Records' },
    { key: 'optimized', header: 'Optimized' },
    { key: 'on_target', header: 'On Target' },
    { key: 'elevated', header: 'Elevated' },
    { key: 'wasteful_or_damage', header: 'Wasteful / Damage' },
    { key: 'total_spend_rupees', header: 'Total Spend (INR)' },
    { key: 'avg_cost_per_shipment', header: 'Avg Cost/Shipment (INR)' },
    { key: 'avg_variance_pct', header: 'Avg Variance %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'pack_category', header: 'Pack Category' },
    { key: 'spend_status', header: 'Spend Status' },
    { key: 'records', header: 'Records' },
    { key: 'total_spend_rupees', header: 'Total Spend (INR)' },
    { key: 'avg_variance_pct', header: 'Avg Variance %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'records', header: 'Records' },
    { key: 'shipments', header: 'Shipments Packed' },
    { key: 'total_spend_rupees', header: 'Total Spend (INR)' },
    { key: 'avg_cost_per_shipment', header: 'Avg Cost/Shipment (INR)' },
    { key: 'damage_incidents', header: 'Damage Incidents' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'avg_savings_potential_rupees', header: 'Avg Savings Potential (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_savings_potential_rupees', header: 'Savings Potential (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const varianceCols: Column<VarianceRow>[] = [
    { key: 'packaging_type', header: 'Packaging Type' },
    { key: 'records', header: 'Records' },
    { key: 'avg_variance_pct', header: 'Avg Variance %' },
    { key: 'max_variance_pct', header: 'Max Variance %' },
    { key: 'total_spend_rupees', header: 'Total Spend (INR)' },
    { key: 'excess_spend_rupees', header: 'Excess vs Target (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'pack_code', header: 'Pack Code' },
    { key: 'packaging_type', header: 'Packaging Type' },
    { key: 'supplier_name', header: 'Supplier' },
    { key: 'pack_category', header: 'Category' },
    { key: 'period_month', header: 'Month' },
    { key: 'spend_status', header: 'Status' },
    { key: 'variance_pct', header: 'Variance %' },
    { key: 'damage_incidents_linked', header: 'Damage Linked' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Packaging-Spend / Dunnage Cost-Optimization Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Packaging &amp; dunnage spend board — pack category (wooden crates, corrugated boxes, foam
        inserts, thermocol, pallet wrap, custom cases) &times; supplier &times; month &times;
        cost-per-shipment vs target &times; variance % &times; reuse % &times; damage-incident
        linkage &times; eco-material share &amp; CAPA closure. Founder-gated view: spend-status
        rollups, supplier scorecards, cost-variance digest, root-cause pareto, and a
        wasteful / damage-prone high-risk queue across Mumbai-Pune, Delhi NCR, Chennai &amp;
        Hyderabad lanes.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Spend status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No packaging spend records logged yet."
          rowKey={(r, i) => String(r.spend_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Supplier packaging scorecard</h2>
        <DataTable
          rows={supplierRows}
          columns={supplierCols}
          emptyMessage="No supplier rollups."
          rowKey={(r, i) => String(r.supplier_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Pack category &times; spend status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No records by pack category."
          rowKey={(r, i) => `${r.pack_category}-${r.spend_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly packaging spend trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Cost-variance digest</h2>
        <DataTable
          rows={varianceRows}
          columns={varianceCols}
          emptyMessage="No cost-variance rollups."
          rowKey={(r, i) => String(r.packaging_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk packaging queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk packaging lines."
          rowKey={(r, i) => `${r.pack_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
