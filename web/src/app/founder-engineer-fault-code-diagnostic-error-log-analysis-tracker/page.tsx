import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = {
  resolution_status: string;
  faults: number;
  total_occurrences: number;
  pct: number;
};
type ModelRow = {
  device_model: string;
  total_faults: number;
  open_faults: number;
  resolved: number;
  recurring: number;
  critical: number;
  total_occurrences: number;
  total_downtime_hours: number;
  resolved_pct: number;
};
type MatrixRow = {
  subsystem: string;
  severity: string;
  faults: number;
  total_occurrences: number;
  total_downtime_hours: number;
};
type TrendRow = {
  fault_month: string;
  faults: number;
  total_occurrences: number;
  resolved: number;
  recurring: number;
  total_downtime_hours: number;
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
type DowntimeRow = {
  subsystem: string;
  faults: number;
  total_occurrences: number;
  total_downtime_hours: number;
  avg_downtime_hours: number;
  recurring_faults: number;
};
type RiskRow = {
  engineer_name: string;
  hospital_name: string;
  device_model: string;
  fault_code: string;
  severity: string;
  subsystem: string;
  occurrences: number;
  last_seen: string;
  resolution_status: string;
  downtime_hours: number | null;
  recurring_flag: boolean | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    modelRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    downtimeRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3444_resolution_status_rollup'),
    supabase.rpc('founder_r3444_device_model_scorecard'),
    supabase.rpc('founder_r3444_subsystem_severity_matrix'),
    supabase.rpc('founder_r3444_monthly_fault_trend'),
    supabase.rpc('founder_r3444_capa_status_board'),
    supabase.rpc('founder_r3444_root_cause_pareto'),
    supabase.rpc('founder_r3444_downtime_impact_digest'),
    supabase.rpc('founder_r3444_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const modelRows: ModelRow[] = (modelRes.data as ModelRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const downtimeRows: DowntimeRow[] = (downtimeRes.data as DowntimeRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'resolution_status', header: 'Resolution Status' },
    { key: 'faults', header: 'Faults' },
    { key: 'total_occurrences', header: 'Occurrences' },
    { key: 'pct', header: 'Share %' },
  ];

  const modelCols: Column<ModelRow>[] = [
    { key: 'device_model', header: 'Device Model' },
    { key: 'total_faults', header: 'Faults' },
    { key: 'open_faults', header: 'Open' },
    { key: 'resolved', header: 'Resolved' },
    { key: 'recurring', header: 'Recurring' },
    { key: 'critical', header: 'Critical' },
    { key: 'total_occurrences', header: 'Occurrences' },
    { key: 'total_downtime_hours', header: 'Downtime (h)' },
    { key: 'resolved_pct', header: 'Resolved %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'subsystem', header: 'Subsystem' },
    { key: 'severity', header: 'Severity' },
    { key: 'faults', header: 'Faults' },
    { key: 'total_occurrences', header: 'Occurrences' },
    { key: 'total_downtime_hours', header: 'Downtime (h)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'fault_month', header: 'Month' },
    { key: 'faults', header: 'Faults' },
    { key: 'total_occurrences', header: 'Occurrences' },
    { key: 'resolved', header: 'Resolved' },
    { key: 'recurring', header: 'Recurring' },
    { key: 'total_downtime_hours', header: 'Downtime (h)' },
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

  const downtimeCols: Column<DowntimeRow>[] = [
    { key: 'subsystem', header: 'Subsystem' },
    { key: 'faults', header: 'Faults' },
    { key: 'total_occurrences', header: 'Occurrences' },
    { key: 'total_downtime_hours', header: 'Total Downtime (h)' },
    { key: 'avg_downtime_hours', header: 'Avg Downtime (h)' },
    { key: 'recurring_faults', header: 'Recurring' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'device_model', header: 'Device Model' },
    { key: 'fault_code', header: 'Fault Code' },
    { key: 'severity', header: 'Severity' },
    { key: 'subsystem', header: 'Subsystem' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'last_seen', header: 'Last Seen' },
    { key: 'resolution_status', header: 'Status' },
    { key: 'downtime_hours', header: 'Downtime (h)' },
    { key: 'recurring_flag', header: 'Recurring' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Device Fault-Code / Diagnostic Error-Log Analysis Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Field-engineer device fault-code &amp; diagnostic error-log capture, analysis and resolution
        tracker — engineer &times; hospital &times; device model &times; fault code &times; severity
        &times; subsystem (power, imaging-chain, mechanical, software, sensor, network, cooling)
        &times; occurrences &times; downtime hours &times; recurrence flag &amp; CAPA closure.
        Founder-gated view: resolution-status rollups, device-model scorecards, root-cause pareto,
        and downtime-impact digests across NABH &amp; CDSCO surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Resolution-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No fault-code logs recorded yet."
          rowKey={(r, i) => String(r.resolution_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Device-model scorecard</h2>
        <DataTable
          rows={modelRows}
          columns={modelCols}
          emptyMessage="No device-model rollups."
          rowKey={(r, i) => String(r.device_model ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Subsystem &times; severity matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No faults by subsystem."
          rowKey={(r, i) => `${r.subsystem}-${r.severity}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly fault trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.fault_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root-cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Downtime-impact digest</h2>
        <DataTable
          rows={downtimeRows}
          columns={downtimeCols}
          emptyMessage="No downtime-impact rollups."
          rowKey={(r, i) => String(r.subsystem ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk fault queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk faults."
          rowKey={(r, i) => `${r.device_model}-${r.fault_code}-${i}`}
        />
      </section>
    </main>
  );
}
