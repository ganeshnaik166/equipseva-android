import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { calibration_status: string; scales: number; pct: number };
type WarehouseRow = {
  warehouse_name: string;
  total_scales: number;
  current_ok: number;
  due_soon: number;
  overdue: number;
  out_of_tolerance: number;
  stamping_lapsed: number;
  avg_accuracy_error_pct: number;
  current_pct: number;
};
type MatrixRow = {
  scale_class: string;
  calibration_status: string;
  scales: number;
  stamping_lapsed: number;
  avg_accuracy_error_pct: number;
};
type TrendRow = {
  period_month: string;
  scales: number;
  current_ok: number;
  overdue: number;
  out_of_tolerance: number;
  stamping_lapsed: number;
  avg_accuracy_error_pct: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  avg_cost_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_rupees: number;
  pct: number;
};
type AccuracyRow = {
  scale_class: string;
  scales: number;
  avg_accuracy_error_pct: number;
  max_accuracy_error_pct: number;
  avg_tolerance_pct: number;
  out_of_tolerance: number;
  stamping_lapsed: number;
};
type RiskRow = {
  warehouse_name: string;
  scale_code: string;
  scale_class: string;
  period_month: string;
  calibration_status: string;
  days_to_due: number | null;
  stamping_valid: boolean;
  accuracy_error_pct: number | null;
  tolerance_pct: number | null;
  trend_dir: string | null;
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
    accuracyRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3687_calibration_status_rollup'),
    supabase.rpc('founder_r3687_warehouse_scorecard'),
    supabase.rpc('founder_r3687_class_status_matrix'),
    supabase.rpc('founder_r3687_monthly_calibration_trend'),
    supabase.rpc('founder_r3687_capa_status_board'),
    supabase.rpc('founder_r3687_root_cause_pareto'),
    supabase.rpc('founder_r3687_accuracy_digest'),
    supabase.rpc('founder_r3687_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const warehouseRows: WarehouseRow[] = (warehouseRes.data as WarehouseRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const accuracyRows: AccuracyRow[] = (accuracyRes.data as AccuracyRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'calibration_status', header: 'Calibration Status' },
    { key: 'scales', header: 'Scales' },
    { key: 'pct', header: 'Share %' },
  ];

  const warehouseCols: Column<WarehouseRow>[] = [
    { key: 'warehouse_name', header: 'Warehouse' },
    { key: 'total_scales', header: 'Scales' },
    { key: 'current_ok', header: 'Current' },
    { key: 'due_soon', header: 'Due Soon' },
    { key: 'overdue', header: 'Overdue' },
    { key: 'out_of_tolerance', header: 'Out of Tol' },
    { key: 'stamping_lapsed', header: 'Stamping Lapsed' },
    { key: 'avg_accuracy_error_pct', header: 'Avg Err %' },
    { key: 'current_pct', header: 'Current %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'scale_class', header: 'Scale Class' },
    { key: 'calibration_status', header: 'Calibration Status' },
    { key: 'scales', header: 'Scales' },
    { key: 'stamping_lapsed', header: 'Stamping Lapsed' },
    { key: 'avg_accuracy_error_pct', header: 'Avg Err %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'scales', header: 'Scales' },
    { key: 'current_ok', header: 'Current' },
    { key: 'overdue', header: 'Overdue' },
    { key: 'out_of_tolerance', header: 'Out of Tol' },
    { key: 'stamping_lapsed', header: 'Stamping Lapsed' },
    { key: 'avg_accuracy_error_pct', header: 'Avg Err %' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const accuracyCols: Column<AccuracyRow>[] = [
    { key: 'scale_class', header: 'Scale Class' },
    { key: 'scales', header: 'Scales' },
    { key: 'avg_accuracy_error_pct', header: 'Avg Err %' },
    { key: 'max_accuracy_error_pct', header: 'Max Err %' },
    { key: 'avg_tolerance_pct', header: 'Avg Tolerance %' },
    { key: 'out_of_tolerance', header: 'Out of Tol' },
    { key: 'stamping_lapsed', header: 'Stamping Lapsed' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'warehouse_name', header: 'Warehouse' },
    { key: 'scale_code', header: 'Scale' },
    { key: 'scale_class', header: 'Class' },
    { key: 'period_month', header: 'Month' },
    { key: 'calibration_status', header: 'Status' },
    { key: 'days_to_due', header: 'Days to Due' },
    { key: 'stamping_valid', header: 'Stamping Valid' },
    { key: 'accuracy_error_pct', header: 'Err %' },
    { key: 'tolerance_pct', header: 'Tol %' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Weighbridge / Weigh-Scale Calibration &amp; Stamping Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Own-warehouse weighbridge and weigh-scale compliance log — scale class (platform, bench,
        crane, pallet beam, counting) &times; warehouse &times; calibration validity &times; legal
        metrology stamping &times; accuracy error vs tolerance &times; usage transactions &times;
        repairs &amp; CAPA closure. Founder-gated view: calibration-status rollups, warehouse
        scorecards, root-cause pareto, and the high-risk queue across Delhi, Mumbai Bhiwandi &amp;
        Chennai warehouses.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Calibration status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No weigh-scale rows logged yet."
          rowKey={(r, i) => String(r.calibration_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Warehouse compliance scorecard</h2>
        <DataTable
          rows={warehouseRows}
          columns={warehouseCols}
          emptyMessage="No warehouse rollups."
          rowKey={(r, i) => String(r.warehouse_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Scale class &times; calibration status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No scales by class."
          rowKey={(r, i) => `${r.scale_class}-${r.calibration_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly calibration trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Accuracy digest by scale class</h2>
        <DataTable
          rows={accuracyRows}
          columns={accuracyCols}
          emptyMessage="No accuracy rollups."
          rowKey={(r, i) => String(r.scale_class ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk scale queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk scales."
          rowKey={(r, i) => `${r.scale_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
