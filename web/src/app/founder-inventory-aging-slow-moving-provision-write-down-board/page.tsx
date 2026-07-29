import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = {
  provision_status: string;
  items: number;
  stock_value_rupees: number;
  provision_rupees: number;
  pct: number;
};
type CategoryRow = {
  item_category: string;
  total_items: number;
  stock_value_rupees: number;
  provision_rupees: number;
  net_realizable_value_rupees: number;
  obsolete_items: number;
  write_off_items: number;
  provision_pct: number;
};
type MatrixRow = {
  aging_bucket: string;
  provision_status: string;
  items: number;
  stock_value_rupees: number;
  provision_rupees: number;
};
type TrendRow = {
  period_month: string;
  items: number;
  stock_value_rupees: number;
  provision_rupees: number;
  net_realizable_value_rupees: number;
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
type DigestRow = {
  warehouse: string;
  items: number;
  stock_value_rupees: number;
  provision_rupees: number;
  net_realizable_value_rupees: number;
  provision_pct: number;
};
type RiskRow = {
  item_code: string;
  item_name: string;
  item_category: string;
  warehouse: string;
  period_month: string;
  aging_bucket: string;
  provision_status: string;
  provision_pct: number;
  provision_rupees: number;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    categoryRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3593_provision_status_rollup'),
    supabase.rpc('founder_r3593_item_category_scorecard'),
    supabase.rpc('founder_r3593_aging_bucket_status_matrix'),
    supabase.rpc('founder_r3593_monthly_provision_trend'),
    supabase.rpc('founder_r3593_capa_status_board'),
    supabase.rpc('founder_r3593_root_cause_pareto'),
    supabase.rpc('founder_r3593_provision_impact_digest'),
    supabase.rpc('founder_r3593_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const categoryRows: CategoryRow[] = (categoryRes.data as CategoryRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'provision_status', header: 'Provision Status' },
    { key: 'items', header: 'Items' },
    { key: 'stock_value_rupees', header: 'Stock Value (INR)' },
    { key: 'provision_rupees', header: 'Provision (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const categoryCols: Column<CategoryRow>[] = [
    { key: 'item_category', header: 'Category' },
    { key: 'total_items', header: 'Items' },
    { key: 'stock_value_rupees', header: 'Stock Value (INR)' },
    { key: 'provision_rupees', header: 'Provision (INR)' },
    { key: 'net_realizable_value_rupees', header: 'NRV (INR)' },
    { key: 'obsolete_items', header: 'Obsolete' },
    { key: 'write_off_items', header: 'Write-Off' },
    { key: 'provision_pct', header: 'Provision %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'aging_bucket', header: 'Aging Bucket' },
    { key: 'provision_status', header: 'Provision Status' },
    { key: 'items', header: 'Items' },
    { key: 'stock_value_rupees', header: 'Stock Value (INR)' },
    { key: 'provision_rupees', header: 'Provision (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Period' },
    { key: 'items', header: 'Items' },
    { key: 'stock_value_rupees', header: 'Stock Value (INR)' },
    { key: 'provision_rupees', header: 'Provision (INR)' },
    { key: 'net_realizable_value_rupees', header: 'NRV (INR)' },
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

  const digestCols: Column<DigestRow>[] = [
    { key: 'warehouse', header: 'Warehouse' },
    { key: 'items', header: 'Items' },
    { key: 'stock_value_rupees', header: 'Stock Value (INR)' },
    { key: 'provision_rupees', header: 'Provision (INR)' },
    { key: 'net_realizable_value_rupees', header: 'NRV (INR)' },
    { key: 'provision_pct', header: 'Provision %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'item_code', header: 'Item Code' },
    { key: 'item_name', header: 'Item' },
    { key: 'item_category', header: 'Category' },
    { key: 'warehouse', header: 'Warehouse' },
    { key: 'period_month', header: 'Period' },
    { key: 'aging_bucket', header: 'Aging Bucket' },
    { key: 'provision_status', header: 'Status' },
    { key: 'provision_pct', header: 'Provision %' },
    { key: 'provision_rupees', header: 'Provision (INR)' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Inventory-Aging / Slow-Moving Provision &amp; Write-Down Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated inventory-aging &amp; slow-moving provisioning board &mdash; SKU aging bucket
        &times; provision status &times; category &times; warehouse &times; net-realizable-value
        write-down &times; days-since-last-movement &times; trend direction &amp; CAPA disposition.
        Tracks stock value at risk, provision coverage, obsolete &amp; write-off exposure, root-cause
        pareto across over-procurement, demand-forecast error, pricing erosion &amp; shelf-life expiry,
        plus the high-risk queue driving liquidation, markdown, return-to-supplier &amp; scrap actions.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Provision status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No inventory aging rows logged yet."
          rowKey={(r, i) => String(r.provision_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Item-category scorecard</h2>
        <DataTable
          rows={categoryRows}
          columns={categoryCols}
          emptyMessage="No category rollups."
          rowKey={(r, i) => String(r.item_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Aging bucket &times; provision status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No matrix data."
          rowKey={(r, i) => `${r.aging_bucket}-${r.provision_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly provision trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Provision-impact digest by warehouse</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No warehouse rollups."
          rowKey={(r, i) => String(r.warehouse ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk (obsolete / write-off) queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk items."
          rowKey={(r, i) => `${r.item_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
