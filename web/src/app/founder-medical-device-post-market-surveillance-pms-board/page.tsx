import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { surveillance_status: string; reports: number; pct: number };
type ClassRow = {
  device_class: string;
  reports: number;
  total_units_in_field: number;
  total_complaints: number;
  avg_complaint_rate_ppm: number;
  total_field_actions: number;
  escalated: number;
  psur_submitted_pct: number;
};
type MatrixRow = {
  device_class: string;
  surveillance_status: string;
  reports: number;
  total_complaints: number;
  avg_complaint_rate_ppm: number;
};
type TrendRow = {
  period_month: string;
  reports: number;
  total_units: number;
  total_complaints: number;
  avg_complaint_rate_ppm: number;
  total_field_actions: number;
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
type SignalRow = {
  trend_signal: string;
  reports: number;
  total_complaints: number;
  avg_complaint_rate_ppm: number;
  total_field_actions: number;
  escalated: number;
};
type RiskRow = {
  device_name: string;
  report_ref: string;
  device_class: string;
  period_month: string;
  surveillance_status: string;
  trend_signal: string;
  trend_dir: string;
  complaint_rate_ppm: number | null;
  field_actions: number | null;
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
    signalRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3641_surveillance_status_rollup'),
    supabase.rpc('founder_r3641_device_class_scorecard'),
    supabase.rpc('founder_r3641_device_class_status_matrix'),
    supabase.rpc('founder_r3641_monthly_complaint_rate_trend'),
    supabase.rpc('founder_r3641_capa_status_board'),
    supabase.rpc('founder_r3641_root_cause_pareto'),
    supabase.rpc('founder_r3641_signal_digest'),
    supabase.rpc('founder_r3641_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const classRows: ClassRow[] = (classRes.data as ClassRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const signalRows: SignalRow[] = (signalRes.data as SignalRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'surveillance_status', header: 'Surveillance Status' },
    { key: 'reports', header: 'Reports' },
    { key: 'pct', header: 'Share %' },
  ];

  const classCols: Column<ClassRow>[] = [
    { key: 'device_class', header: 'Device Class' },
    { key: 'reports', header: 'Reports' },
    { key: 'total_units_in_field', header: 'Units in Field' },
    { key: 'total_complaints', header: 'Complaints' },
    { key: 'avg_complaint_rate_ppm', header: 'Avg Rate ppm' },
    { key: 'total_field_actions', header: 'Field Actions' },
    { key: 'escalated', header: 'Escalated' },
    { key: 'psur_submitted_pct', header: 'PSUR Submitted %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'device_class', header: 'Device Class' },
    { key: 'surveillance_status', header: 'Status' },
    { key: 'reports', header: 'Reports' },
    { key: 'total_complaints', header: 'Complaints' },
    { key: 'avg_complaint_rate_ppm', header: 'Avg Rate ppm' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Period' },
    { key: 'reports', header: 'Reports' },
    { key: 'total_units', header: 'Units in Field' },
    { key: 'total_complaints', header: 'Complaints' },
    { key: 'avg_complaint_rate_ppm', header: 'Avg Rate ppm' },
    { key: 'total_field_actions', header: 'Field Actions' },
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

  const signalCols: Column<SignalRow>[] = [
    { key: 'trend_signal', header: 'Trend Signal' },
    { key: 'reports', header: 'Reports' },
    { key: 'total_complaints', header: 'Complaints' },
    { key: 'avg_complaint_rate_ppm', header: 'Avg Rate ppm' },
    { key: 'total_field_actions', header: 'Field Actions' },
    { key: 'escalated', header: 'Escalated' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'device_name', header: 'Device' },
    { key: 'report_ref', header: 'Report Ref' },
    { key: 'device_class', header: 'Class' },
    { key: 'period_month', header: 'Period' },
    { key: 'surveillance_status', header: 'Status' },
    { key: 'trend_signal', header: 'Signal' },
    { key: 'trend_dir', header: 'Trend' },
    { key: 'complaint_rate_ppm', header: 'Rate ppm' },
    { key: 'field_actions', header: 'Field Actions' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Medical-Device Post-Market Surveillance (PMS) Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Post-market surveillance &amp; PSUR log across the medical-device portfolio (ICU ventilators,
        infusion &amp; syringe pumps, patient monitors, dialysis machines, defibrillators, C-arms,
        pulse oximeters, CT scanners, diathermy units, infant warmers) &mdash; device &times; class
        &times; period &times; units-in-field &times; complaints &times; complaint-rate ppm &times;
        field actions &times; signal detection &times; PMS/PSUR status &amp; CAPA closure.
        Founder-gated view: surveillance-status rollups, device-class scorecards, root-cause pareto,
        and signal digests across CDSCO &amp; ISO 13485 surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Surveillance status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No surveillance reports logged yet."
          rowKey={(r, i) => String(r.surveillance_status ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Device-class &times; surveillance-status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No reports by device class."
          rowKey={(r, i) => `${r.device_class}-${r.surveillance_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly complaint-rate trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Signal digest</h2>
        <DataTable
          rows={signalRows}
          columns={signalCols}
          emptyMessage="No signal digest data."
          rowKey={(r, i) => String(r.trend_signal ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk surveillance queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk reports."
          rowKey={(r, i) => `${r.report_ref}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
