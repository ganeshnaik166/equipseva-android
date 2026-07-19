import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = {
  inventory_verdict: string;
  skus: number;
  total_value_rupees: number;
  total_provision_rupees: number;
  pct: number;
};
type StoreRow = {
  store_location: string;
  total_skus: number;
  healthy: number;
  watch: number;
  provision_needed: number;
  write_down_now: number;
  dispose: number;
  total_value_rupees: number;
  total_provision_rupees: number;
};
type MatrixRow = {
  equipment_family: string;
  movement_class: string;
  skus: number;
  total_value_rupees: number;
  total_provision_rupees: number;
  avg_months_since_movement: number;
};
type TrendRow = {
  last_movement_date: string;
  skus: number;
  total_value_rupees: number;
  non_moving_skus: number;
  dead_or_obsolete_skus: number;
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
type FinRow = {
  financial_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  store_location: string;
  part_sku: string;
  part_name: string;
  equipment_family: string;
  on_hand_qty: number;
  on_hand_value_rupees: number;
  months_since_movement: number;
  movement_class: string;
  inventory_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    storeRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    finRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3329_inventory_verdict_rollup'),
    supabase.rpc('founder_r3329_store_scorecard'),
    supabase.rpc('founder_r3329_family_movement_matrix'),
    supabase.rpc('founder_r3329_movement_date_trend'),
    supabase.rpc('founder_r3329_capa_status_board'),
    supabase.rpc('founder_r3329_root_cause_pareto'),
    supabase.rpc('founder_r3329_financial_impact_digest'),
    supabase.rpc('founder_r3329_high_risk_stock_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const storeRows: StoreRow[] = (storeRes.data as StoreRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const finRows: FinRow[] = (finRes.data as FinRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'inventory_verdict', header: 'Inventory Verdict' },
    { key: 'skus', header: 'SKUs' },
    { key: 'total_value_rupees', header: 'On-Hand Value (INR)' },
    { key: 'total_provision_rupees', header: 'Provision (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const storeCols: Column<StoreRow>[] = [
    { key: 'store_location', header: 'Store' },
    { key: 'total_skus', header: 'SKUs' },
    { key: 'healthy', header: 'Healthy' },
    { key: 'watch', header: 'Watch' },
    { key: 'provision_needed', header: 'Provision Needed' },
    { key: 'write_down_now', header: 'Write-Down Now' },
    { key: 'dispose', header: 'Dispose' },
    { key: 'total_value_rupees', header: 'On-Hand Value (INR)' },
    { key: 'total_provision_rupees', header: 'Provision (INR)' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'equipment_family', header: 'Equipment Family' },
    { key: 'movement_class', header: 'Movement Class' },
    { key: 'skus', header: 'SKUs' },
    { key: 'total_value_rupees', header: 'On-Hand Value (INR)' },
    { key: 'total_provision_rupees', header: 'Provision (INR)' },
    { key: 'avg_months_since_movement', header: 'Avg Months Idle' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'last_movement_date', header: 'Last Movement' },
    { key: 'skus', header: 'SKUs' },
    { key: 'total_value_rupees', header: 'On-Hand Value (INR)' },
    { key: 'non_moving_skus', header: 'Non-Moving' },
    { key: 'dead_or_obsolete_skus', header: 'Dead / Obsolete' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Exposure (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Exposure (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const finCols: Column<FinRow>[] = [
    { key: 'financial_impact', header: 'Financial Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Exposure (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'store_location', header: 'Store' },
    { key: 'part_sku', header: 'SKU' },
    { key: 'part_name', header: 'Part' },
    { key: 'equipment_family', header: 'Family' },
    { key: 'on_hand_qty', header: 'Qty' },
    { key: 'on_hand_value_rupees', header: 'Value (INR)' },
    { key: 'months_since_movement', header: 'Months Idle' },
    { key: 'movement_class', header: 'Movement' },
    { key: 'inventory_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Spare-Parts Obsolescence, Slow-Moving &amp; Inventory Write-Down Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Inventory-finance governance across EquipSeva stores — store &times; equipment family &times;
        on-hand value &times; months-since-movement &times; movement class &times; installed-base
        linkage &times; shelf-life &times; provision % &times; disposal route &times; inventory verdict
        &amp; CAPA closure. Founder-gated view: verdict rollups, store scorecards, root-cause pareto,
        and financial-impact digest for slow-moving, dead-stock &amp; write-down decisions.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Inventory verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No spare-parts stock logged yet."
          rowKey={(r, i) => String(r.inventory_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Store obsolescence scorecard</h2>
        <DataTable
          rows={storeRows}
          columns={storeCols}
          emptyMessage="No store rollups."
          rowKey={(r, i) => String(r.store_location ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Equipment family &times; movement class matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No stock by family."
          rowKey={(r, i) => `${r.equipment_family}-${r.movement_class}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Last-movement date trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.last_movement_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Financial impact digest</h2>
        <DataTable
          rows={finRows}
          columns={finCols}
          emptyMessage="No financial-impact rollups."
          rowKey={(r, i) => String(r.financial_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk stock queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk stock."
          rowKey={(r, i) => `${r.part_sku}-${i}`}
        />
      </section>
    </main>
  );
}
