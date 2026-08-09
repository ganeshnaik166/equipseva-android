import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { safety_status: string; mhe_units: number; pct: number };
type WhRow = {
  warehouse_name: string;
  mhe_units: number;
  safe_units: number;
  minor_defect_units: number;
  repair_due_units: number;
  load_test_overdue_units: number;
  unsafe_units: number;
  total_defects: number;
  unauthorized_use_events: number;
  avg_inspection_pct: number;
  safe_pct: number;
};
type MatrixRow = {
  mhe_class: string;
  safety_status: string;
  mhe_units: number;
  avg_age_years: number;
  defects: number;
};
type TrendRow = {
  period_month: string;
  mhe_units: number;
  inspections_due: number;
  inspections_done: number;
  avg_inspection_pct: number;
  defects_found: number;
  downtime_hours: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_downtime_impact_hours: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_downtime_impact_hours: number;
  pct: number;
};
type DigestRow = {
  mhe_class: string;
  mhe_units: number;
  total_defects: number;
  hydraulic_leaks: number;
  downtime_hours: number;
  unauthorized_use_events: number;
};
type RiskRow = {
  warehouse_name: string;
  equipment_code: string;
  mhe_class: string;
  period_month: string;
  safety_status: string;
  defects_found: number;
  hydraulic_leaks: number;
  load_test_current: boolean;
  downtime_hours: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    whRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3686_safety_status_rollup'),
    supabase.rpc('founder_r3686_warehouse_scorecard'),
    supabase.rpc('founder_r3686_class_status_matrix'),
    supabase.rpc('founder_r3686_monthly_inspection_trend'),
    supabase.rpc('founder_r3686_capa_status_board'),
    supabase.rpc('founder_r3686_root_cause_pareto'),
    supabase.rpc('founder_r3686_defect_digest'),
    supabase.rpc('founder_r3686_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const whRows: WhRow[] = (whRes.data as WhRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'safety_status', header: 'Safety Status' },
    { key: 'mhe_units', header: 'Units' },
    { key: 'pct', header: 'Share %' },
  ];

  const whCols: Column<WhRow>[] = [
    { key: 'warehouse_name', header: 'Warehouse' },
    { key: 'mhe_units', header: 'Units' },
    { key: 'safe_units', header: 'Safe' },
    { key: 'minor_defect_units', header: 'Minor Defects' },
    { key: 'repair_due_units', header: 'Repair Due' },
    { key: 'load_test_overdue_units', header: 'Load Test Overdue' },
    { key: 'unsafe_units', header: 'Unsafe' },
    { key: 'total_defects', header: 'Defects' },
    { key: 'unauthorized_use_events', header: 'Unauthorized Use' },
    { key: 'avg_inspection_pct', header: 'Avg Inspection %' },
    { key: 'safe_pct', header: 'Safe %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'mhe_class', header: 'MHE Class' },
    { key: 'safety_status', header: 'Safety Status' },
    { key: 'mhe_units', header: 'Units' },
    { key: 'avg_age_years', header: 'Avg Age (yrs)' },
    { key: 'defects', header: 'Defects' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'mhe_units', header: 'Units' },
    { key: 'inspections_due', header: 'Inspections Due' },
    { key: 'inspections_done', header: 'Inspections Done' },
    { key: 'avg_inspection_pct', header: 'Avg Inspection %' },
    { key: 'defects_found', header: 'Defects' },
    { key: 'downtime_hours', header: 'Downtime Hrs' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_downtime_impact_hours', header: 'Avg Downtime Impact Hrs' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_downtime_impact_hours', header: 'Total Downtime Impact Hrs' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'mhe_class', header: 'MHE Class' },
    { key: 'mhe_units', header: 'Units' },
    { key: 'total_defects', header: 'Defects' },
    { key: 'hydraulic_leaks', header: 'Hydraulic Leaks' },
    { key: 'downtime_hours', header: 'Downtime Hrs' },
    { key: 'unauthorized_use_events', header: 'Unauthorized Use' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'warehouse_name', header: 'Warehouse' },
    { key: 'equipment_code', header: 'Equipment' },
    { key: 'mhe_class', header: 'Class' },
    { key: 'period_month', header: 'Month' },
    { key: 'safety_status', header: 'Status' },
    { key: 'defects_found', header: 'Defects' },
    { key: 'hydraulic_leaks', header: 'Leaks' },
    { key: 'load_test_current', header: 'Load Test Current' },
    { key: 'downtime_hours', header: 'Downtime Hrs' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Forklift / MHE Own-Fleet Safety-Inspection Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Own-warehouse forklift &amp; material-handling-equipment safety log — MHE class
        (counterbalance forklifts, reach trucks, pallet jacks, stackers, powered hand trolleys)
        &times; warehouse &times; inspection completion &times; defects &times; hydraulic leaks
        &times; load-test currency &times; operator authorization &times; downtime hours &amp; CAPA
        closure. Founder-gated view: safety-status rollups, warehouse scorecards, root-cause
        pareto, and the high-risk queue across Delhi, Mumbai Bhiwandi &amp; Chennai warehouses.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Safety status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No inspection entries logged yet."
          rowKey={(r, i) => String(r.safety_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Warehouse safety scorecard</h2>
        <DataTable
          rows={whRows}
          columns={whCols}
          emptyMessage="No warehouse rollups."
          rowKey={(r, i) => String(r.warehouse_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. MHE class &times; safety status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No entries by MHE class."
          rowKey={(r, i) => `${r.mhe_class}-${r.safety_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly inspection trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Defect &amp; downtime digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No defect digest rollups."
          rowKey={(r, i) => String(r.mhe_class ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk equipment queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk equipment."
          rowKey={(r, i) => `${r.equipment_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
