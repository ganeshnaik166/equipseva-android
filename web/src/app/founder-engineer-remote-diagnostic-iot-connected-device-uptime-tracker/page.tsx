import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type ConnRow = { connectivity_status: string; devices: number; pct: number };
type RegionRow = {
  region: string;
  records: number;
  avg_uptime_pct: number;
  avg_remote_resolution_pct: number;
  total_devices_connected: number;
  total_telemetry_alerts: number;
  total_truck_rolls_avoided: number;
  degraded_or_worse: number;
};
type MatrixRow = {
  alert_severity: string;
  connectivity_status: string;
  records: number;
  avg_uptime_pct: number;
  total_alerts: number;
};
type TrendRow = {
  period_month: string;
  records: number;
  avg_uptime_pct: number;
  avg_remote_resolution_pct: number;
  total_alerts: number;
  total_resolved_remote: number;
  total_truck_rolls_avoided: number;
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
type ImpactRow = {
  sla_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type RiskRow = {
  engineer_name: string;
  region: string;
  device_model: string;
  device_serial: string;
  period_month: string;
  connectivity_status: string;
  alert_severity: string;
  uptime_pct: number;
  remote_resolution_pct: number;
  mean_resolution_hrs: number;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    connRes,
    regionRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3584_connectivity_status_rollup'),
    supabase.rpc('founder_r3584_region_scorecard'),
    supabase.rpc('founder_r3584_severity_connectivity_matrix'),
    supabase.rpc('founder_r3584_monthly_uptime_trend'),
    supabase.rpc('founder_r3584_capa_status_board'),
    supabase.rpc('founder_r3584_root_cause_pareto'),
    supabase.rpc('founder_r3584_uptime_impact_digest'),
    supabase.rpc('founder_r3584_high_risk_queue'),
  ]);

  const connRows: ConnRow[] = (connRes.data as ConnRow[]) ?? [];
  const regionRows: RegionRow[] = (regionRes.data as RegionRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const connCols: Column<ConnRow>[] = [
    { key: 'connectivity_status', header: 'Connectivity Status' },
    { key: 'devices', header: 'Records' },
    { key: 'pct', header: 'Share %' },
  ];

  const regionCols: Column<RegionRow>[] = [
    { key: 'region', header: 'Region' },
    { key: 'records', header: 'Records' },
    { key: 'avg_uptime_pct', header: 'Avg Uptime %' },
    { key: 'avg_remote_resolution_pct', header: 'Avg Remote Res %' },
    { key: 'total_devices_connected', header: 'Devices Connected' },
    { key: 'total_telemetry_alerts', header: 'Telemetry Alerts' },
    { key: 'total_truck_rolls_avoided', header: 'Truck Rolls Avoided' },
    { key: 'degraded_or_worse', header: 'Degraded+' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'alert_severity', header: 'Alert Severity' },
    { key: 'connectivity_status', header: 'Connectivity Status' },
    { key: 'records', header: 'Records' },
    { key: 'avg_uptime_pct', header: 'Avg Uptime %' },
    { key: 'total_alerts', header: 'Total Alerts' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'records', header: 'Records' },
    { key: 'avg_uptime_pct', header: 'Avg Uptime %' },
    { key: 'avg_remote_resolution_pct', header: 'Avg Remote Res %' },
    { key: 'total_alerts', header: 'Total Alerts' },
    { key: 'total_resolved_remote', header: 'Resolved Remote' },
    { key: 'total_truck_rolls_avoided', header: 'Truck Rolls Avoided' },
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

  const impactCols: Column<ImpactRow>[] = [
    { key: 'sla_impact', header: 'SLA Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'region', header: 'Region' },
    { key: 'device_model', header: 'Device Model' },
    { key: 'device_serial', header: 'Serial' },
    { key: 'period_month', header: 'Month' },
    { key: 'connectivity_status', header: 'Connectivity' },
    { key: 'alert_severity', header: 'Severity' },
    { key: 'uptime_pct', header: 'Uptime %' },
    { key: 'remote_resolution_pct', header: 'Remote Res %' },
    { key: 'mean_resolution_hrs', header: 'Mean Res Hrs' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Remote-Diagnostic / IoT-Connected Device Uptime Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Remote-diagnostic &amp; IoT-connected medical-device uptime and telemetry-resolution log —
        engineer &times; region &times; device model &times; month &times; devices connected &times;
        uptime % &times; telemetry alerts &times; alerts resolved remotely &times; remote-resolution %
        &times; mean-resolution hours &times; truck-rolls avoided &times; connectivity status &times;
        alert severity &amp; CAPA closure. Founder-gated view: connectivity distribution, region
        scorecards, root-cause pareto, and SLA-impact digest across the connected-device fleet.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Connectivity-status distribution</h2>
        <DataTable
          rows={connRows}
          columns={connCols}
          emptyMessage="No telemetry records logged yet."
          rowKey={(r, i) => String(r.connectivity_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Region scorecard</h2>
        <DataTable
          rows={regionRows}
          columns={regionCols}
          emptyMessage="No region rollups."
          rowKey={(r, i) => String(r.region ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Alert severity &times; connectivity matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No records by severity."
          rowKey={(r, i) => `${r.alert_severity}-${r.connectivity_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly uptime trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Uptime-impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No SLA-impact rollups."
          rowKey={(r, i) => String(r.sla_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk uptime queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk devices."
          rowKey={(r, i) => `${r.device_serial}-${r.period_month}-${i}`}
        />
      </section>
    </main>
  );
}
