import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { pickpack_status: string; entries: number; pct: number };
type WarehouseRow = {
  warehouse_name: string;
  entries: number;
  total_orders_picked: number;
  total_pick_errors: number;
  avg_pick_accuracy_pct: number;
  avg_pick_time_minutes: number;
  total_mis_slotted_bins: number;
  total_dispatch_errors: number;
  total_returns_due_to_pick_error: number;
};
type MatrixRow = {
  zone_class: string;
  pickpack_status: string;
  entries: number;
  avg_pick_accuracy_pct: number;
  avg_dispatch_errors: number;
};
type TrendRow = {
  period_month: string;
  entries: number;
  total_orders_picked: number;
  avg_pick_accuracy_pct: number;
  avg_pick_time_minutes: number;
  high_error_entries: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_days_to_target: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string | null;
  occurrences: number;
  pct: number;
};
type MisSlotRow = {
  warehouse_name: string;
  zone: string;
  entries: number;
  total_mis_slotted_bins: number;
  avg_mis_slotted_bins: number;
  high_mis_slot_entries: number;
};
type RiskRow = {
  warehouse_name: string;
  zone: string;
  zone_class: string;
  period_month: string;
  pick_accuracy_pct: number | null;
  dispatch_errors: number | null;
  mis_slotted_bins: number | null;
  pickpack_status: string;
  trend_dir: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    warehouseRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    misSlotRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3721_pickpack_status_rollup'),
    supabase.rpc('founder_r3721_warehouse_scorecard'),
    supabase.rpc('founder_r3721_zone_class_status_matrix'),
    supabase.rpc('founder_r3721_monthly_accuracy_trend'),
    supabase.rpc('founder_r3721_capa_status_board'),
    supabase.rpc('founder_r3721_root_cause_pareto'),
    supabase.rpc('founder_r3721_mis_slot_digest'),
    supabase.rpc('founder_r3721_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const warehouseRows: WarehouseRow[] = (warehouseRes.data as WarehouseRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const misSlotRows: MisSlotRow[] = (misSlotRes.data as MisSlotRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'pickpack_status', header: 'Pick-Pack Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'pct', header: 'Share %' },
  ];

  const warehouseCols: Column<WarehouseRow>[] = [
    { key: 'warehouse_name', header: 'Warehouse' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_orders_picked', header: 'Orders Picked' },
    { key: 'total_pick_errors', header: 'Pick Errors' },
    { key: 'avg_pick_accuracy_pct', header: 'Avg Accuracy %' },
    { key: 'avg_pick_time_minutes', header: 'Avg Pick Time (min)' },
    { key: 'total_mis_slotted_bins', header: 'Mis-Slotted Bins' },
    { key: 'total_dispatch_errors', header: 'Dispatch Errors' },
    { key: 'total_returns_due_to_pick_error', header: 'Returns from Pick Error' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'zone_class', header: 'Zone Class' },
    { key: 'pickpack_status', header: 'Pick-Pack Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'avg_pick_accuracy_pct', header: 'Avg Accuracy %' },
    { key: 'avg_dispatch_errors', header: 'Avg Dispatch Errors' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_orders_picked', header: 'Orders Picked' },
    { key: 'avg_pick_accuracy_pct', header: 'Avg Accuracy %' },
    { key: 'avg_pick_time_minutes', header: 'Avg Pick Time (min)' },
    { key: 'high_error_entries', header: 'High / Critical Error Entries' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_days_to_target', header: 'Avg Days to Target Close' },
    { key: 'overdue_flag', header: 'Overdue' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'pct', header: 'Share %' },
  ];

  const misSlotCols: Column<MisSlotRow>[] = [
    { key: 'warehouse_name', header: 'Warehouse' },
    { key: 'zone', header: 'Zone' },
    { key: 'entries', header: 'Entries' },
    { key: 'total_mis_slotted_bins', header: 'Total Mis-Slotted Bins' },
    { key: 'avg_mis_slotted_bins', header: 'Avg Mis-Slotted Bins' },
    { key: 'high_mis_slot_entries', header: 'High Mis-Slot Entries' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'warehouse_name', header: 'Warehouse' },
    { key: 'zone', header: 'Zone' },
    { key: 'zone_class', header: 'Zone Class' },
    { key: 'period_month', header: 'Month' },
    { key: 'pick_accuracy_pct', header: 'Accuracy %' },
    { key: 'dispatch_errors', header: 'Dispatch Errors' },
    { key: 'mis_slotted_bins', header: 'Mis-Slotted Bins' },
    { key: 'pickpack_status', header: 'Status' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Warehouse Pick-Pack Accuracy &amp; Dispatch Slotting Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        In-warehouse picking, bin-slotting &amp; dispatch operational accuracy &mdash; warehouse
        &times; zone &times; zone class (fast-moving, slow-moving, bulky/oversized, high-value
        secure, returns staging) &times; orders picked &times; pick errors &times; pick accuracy
        &times; avg pick time &times; mis-slotted bins &times; dispatch errors &times; returns from
        pick error &times; relabeling required &amp; CAPA closure. Founder-gated view: status
        rollups, warehouse scorecards, zone-class matrices, monthly accuracy trend, root-cause
        pareto, the mis-slot digest, and the high-error / critical-error queue.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Pick-pack status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No pick-pack entries logged yet."
          rowKey={(r, i) => String(r.pickpack_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Warehouse scorecard</h2>
        <DataTable
          rows={warehouseRows}
          columns={warehouseCols}
          emptyMessage="No warehouse rollups."
          rowKey={(r, i) => String(r.warehouse_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Zone class &times; pick-pack status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No entries by zone class."
          rowKey={(r, i) => `${r.zone_class}-${r.pickpack_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly accuracy trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Mis-slot digest</h2>
        <DataTable
          rows={misSlotRows}
          columns={misSlotCols}
          emptyMessage="No mis-slotting rollups."
          rowKey={(r, i) => `${r.warehouse_name}-${r.zone}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-error or critical-error entries."
          rowKey={(r, i) => `${r.warehouse_name}-${r.zone}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
