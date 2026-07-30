import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { udi_status: string; devices: number; units_covered: number; pct: number };
type ClassRow = {
  device_class: string;
  total_devices: number;
  fully_compliant: number;
  labeling_gap: number;
  database_gap: number;
  not_assigned: number;
  non_compliant: number;
  avg_labels_pct: number;
  avg_database_pct: number;
  compliant_pct: number;
};
type MatrixRow = {
  device_class: string;
  udi_status: string;
  devices: number;
  units_covered: number;
  avg_labels_pct: number;
};
type TrendRow = {
  period_month: string;
  devices: number;
  fully_compliant: number;
  avg_labels_pct: number;
  avg_database_pct: number;
  avg_batch_lot_pct: number;
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
type GapRow = {
  device_class: string;
  devices_with_gap: number;
  units_affected: number;
  avg_labels_pct: number;
  avg_database_pct: number;
  avg_batch_lot_pct: number;
};
type RiskRow = {
  device_name: string;
  device_code: string;
  device_class: string;
  period_month: string;
  udi_di: string | null;
  udi_status: string;
  labels_compliant_pct: number | null;
  database_uploaded_pct: number | null;
  trend_dir: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    classRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    gapRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3639_udi_status_rollup'),
    supabase.rpc('founder_r3639_device_class_scorecard'),
    supabase.rpc('founder_r3639_class_status_matrix'),
    supabase.rpc('founder_r3639_monthly_compliance_trend'),
    supabase.rpc('founder_r3639_capa_status_board'),
    supabase.rpc('founder_r3639_root_cause_pareto'),
    supabase.rpc('founder_r3639_labeling_gap_digest'),
    supabase.rpc('founder_r3639_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const classRows: ClassRow[] = (classRes.data as ClassRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const gapRows: GapRow[] = (gapRes.data as GapRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'udi_status', header: 'UDI Status' },
    { key: 'devices', header: 'Devices' },
    { key: 'units_covered', header: 'Units Covered' },
    { key: 'pct', header: 'Share %' },
  ];

  const classCols: Column<ClassRow>[] = [
    { key: 'device_class', header: 'Device Class' },
    { key: 'total_devices', header: 'Devices' },
    { key: 'fully_compliant', header: 'Fully Compliant' },
    { key: 'labeling_gap', header: 'Labeling Gap' },
    { key: 'database_gap', header: 'Database Gap' },
    { key: 'not_assigned', header: 'Not Assigned' },
    { key: 'non_compliant', header: 'Non-Compliant' },
    { key: 'avg_labels_pct', header: 'Avg Labels %' },
    { key: 'avg_database_pct', header: 'Avg Database %' },
    { key: 'compliant_pct', header: 'Compliant %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'device_class', header: 'Device Class' },
    { key: 'udi_status', header: 'UDI Status' },
    { key: 'devices', header: 'Devices' },
    { key: 'units_covered', header: 'Units Covered' },
    { key: 'avg_labels_pct', header: 'Avg Labels %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'devices', header: 'Devices' },
    { key: 'fully_compliant', header: 'Fully Compliant' },
    { key: 'avg_labels_pct', header: 'Avg Labels %' },
    { key: 'avg_database_pct', header: 'Avg Database %' },
    { key: 'avg_batch_lot_pct', header: 'Avg Batch-Lot %' },
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

  const gapCols: Column<GapRow>[] = [
    { key: 'device_class', header: 'Device Class' },
    { key: 'devices_with_gap', header: 'Devices w/ Gap' },
    { key: 'units_affected', header: 'Units Affected' },
    { key: 'avg_labels_pct', header: 'Avg Labels %' },
    { key: 'avg_database_pct', header: 'Avg Database %' },
    { key: 'avg_batch_lot_pct', header: 'Avg Batch-Lot %' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'device_name', header: 'Device' },
    { key: 'device_code', header: 'Code' },
    { key: 'device_class', header: 'Class' },
    { key: 'period_month', header: 'Month' },
    { key: 'udi_di', header: 'UDI-DI' },
    { key: 'udi_status', header: 'Status' },
    { key: 'labels_compliant_pct', header: 'Labels %' },
    { key: 'database_uploaded_pct', header: 'Database %' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Medical-Device UDI (Unique Device Identification) Traceability Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Per-device UDI traceability log — device class (CDSCO Class A&ndash;D) &times; period &times;
        DI/PI assignment &times; label compliance &times; CDSCO-database upload &times; batch-lot
        linkage &times; GTIN assignment &times; direct part marking &amp; CAPA closure. Founder-gated
        view: UDI-status distribution, device-class scorecards, class &times; status matrix, monthly
        compliance trend, root-cause pareto, and labeling-gap digest across CDSCO &amp; MDR-2017 surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. UDI status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No UDI records logged yet."
          rowKey={(r, i) => String(r.udi_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Device-class scorecard</h2>
        <DataTable
          rows={classRows}
          columns={classCols}
          emptyMessage="No device-class rollups."
          rowKey={(r, i) => String(r.device_class ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Device class &times; UDI status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No records by device class."
          rowKey={(r, i) => `${r.device_class}-${r.udi_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly compliance trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Labeling-gap digest</h2>
        <DataTable
          rows={gapRows}
          columns={gapCols}
          emptyMessage="No labeling-gap data."
          rowKey={(r, i) => String(r.device_class ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk UDI queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk devices."
          rowKey={(r, i) => `${r.device_code}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
