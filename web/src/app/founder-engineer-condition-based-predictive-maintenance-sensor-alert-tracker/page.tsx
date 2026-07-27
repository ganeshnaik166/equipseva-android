import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type SeverityRow = { anomaly_severity: string; alerts: number; pct: number };
type SensorRow = {
  sensor_type: string;
  total_alerts: number;
  critical: number;
  warning: number;
  watch: number;
  unresolved: number;
  false_alarms: number;
  avg_predicted_failure_days: number;
  critical_pct: number;
};
type MatrixRow = {
  sensor_type: string;
  anomaly_severity: string;
  alerts: number;
  resolved_count: number;
  unresolved: number;
  avg_predicted_failure_days: number;
};
type TrendRow = {
  alert_month: string;
  alerts: number;
  critical: number;
  warning: number;
  unresolved: number;
  parts_replaced: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_downtime_avoided_hours: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_downtime_avoided_hours: number;
  pct: number;
};
type DigestRow = {
  corrective_action: string;
  findings: number;
  total_downtime_avoided_hours: number;
  total_savings_rupees: number;
  closed_count: number;
};
type RiskRow = {
  hospital_name: string;
  asset_tag: string;
  device_model: string;
  sensor_type: string;
  alert_date: string;
  anomaly_severity: string;
  reading_value: number | null;
  threshold_value: number | null;
  predicted_failure_days: number | null;
  action_taken: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    severityRes,
    sensorRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3480_anomaly_severity_rollup'),
    supabase.rpc('founder_r3480_sensor_type_scorecard'),
    supabase.rpc('founder_r3480_sensor_severity_matrix'),
    supabase.rpc('founder_r3480_monthly_alert_trend'),
    supabase.rpc('founder_r3480_capa_status_board'),
    supabase.rpc('founder_r3480_root_cause_pareto'),
    supabase.rpc('founder_r3480_downtime_avoidance_digest'),
    supabase.rpc('founder_r3480_high_risk_queue'),
  ]);

  const severityRows: SeverityRow[] = (severityRes.data as SeverityRow[]) ?? [];
  const sensorRows: SensorRow[] = (sensorRes.data as SensorRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const severityCols: Column<SeverityRow>[] = [
    { key: 'anomaly_severity', header: 'Severity' },
    { key: 'alerts', header: 'Alerts' },
    { key: 'pct', header: 'Share %' },
  ];

  const sensorCols: Column<SensorRow>[] = [
    { key: 'sensor_type', header: 'Sensor Type' },
    { key: 'total_alerts', header: 'Alerts' },
    { key: 'critical', header: 'Critical' },
    { key: 'warning', header: 'Warning' },
    { key: 'watch', header: 'Watch' },
    { key: 'unresolved', header: 'Unresolved' },
    { key: 'false_alarms', header: 'False Alarms' },
    { key: 'avg_predicted_failure_days', header: 'Avg Predicted-Failure Days' },
    { key: 'critical_pct', header: 'Critical %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'sensor_type', header: 'Sensor Type' },
    { key: 'anomaly_severity', header: 'Severity' },
    { key: 'alerts', header: 'Alerts' },
    { key: 'resolved_count', header: 'Resolved' },
    { key: 'unresolved', header: 'Unresolved' },
    { key: 'avg_predicted_failure_days', header: 'Avg Predicted-Failure Days' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'alert_month', header: 'Month' },
    { key: 'alerts', header: 'Alerts' },
    { key: 'critical', header: 'Critical' },
    { key: 'warning', header: 'Warning' },
    { key: 'unresolved', header: 'Unresolved' },
    { key: 'parts_replaced', header: 'Parts Replaced' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_downtime_avoided_hours', header: 'Avg Downtime Avoided (hrs)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_downtime_avoided_hours', header: 'Downtime Avoided (hrs)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'corrective_action', header: 'Corrective Action' },
    { key: 'findings', header: 'Findings' },
    { key: 'total_downtime_avoided_hours', header: 'Downtime Avoided (hrs)' },
    { key: 'total_savings_rupees', header: 'Savings (INR)' },
    { key: 'closed_count', header: 'Closed' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'asset_tag', header: 'Asset' },
    { key: 'device_model', header: 'Model' },
    { key: 'sensor_type', header: 'Sensor' },
    { key: 'alert_date', header: 'Date' },
    { key: 'anomaly_severity', header: 'Severity' },
    { key: 'reading_value', header: 'Reading' },
    { key: 'threshold_value', header: 'Threshold' },
    { key: 'predicted_failure_days', header: 'Pred. Fail Days' },
    { key: 'action_taken', header: 'Action' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Condition-Based / Predictive-Maintenance Sensor-Alert Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Condition-based monitoring sensor-alert &rarr; intervention log — sensor type (vibration,
        temperature, current, acoustic, pressure, runtime-hours, error-rate) &times; anomaly severity
        &times; reading vs threshold &times; predicted-failure horizon &times; action taken &times;
        resolution &amp; CAPA closure. Founder-gated view: severity distribution, sensor-type
        scorecards, root-cause pareto, and downtime-avoidance impact across the fleet.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Anomaly severity distribution</h2>
        <DataTable
          rows={severityRows}
          columns={severityCols}
          emptyMessage="No sensor alerts logged yet."
          rowKey={(r, i) => String(r.anomaly_severity ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Sensor-type scorecard</h2>
        <DataTable
          rows={sensorRows}
          columns={sensorCols}
          emptyMessage="No sensor-type rollups."
          rowKey={(r, i) => String(r.sensor_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Sensor type &times; severity matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No alerts by sensor type."
          rowKey={(r, i) => `${r.sensor_type}-${r.anomaly_severity}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly alert trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.alert_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Downtime-avoidance impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No downtime-avoidance data."
          rowKey={(r, i) => String(r.corrective_action ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk alert queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk alerts."
          rowKey={(r, i) => `${r.asset_tag}-${r.alert_date}-${i}`}
        />
      </section>
    </main>
  );
}
