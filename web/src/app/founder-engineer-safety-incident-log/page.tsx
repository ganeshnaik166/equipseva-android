import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerSafetyIncidentLogPage() {
  const supabase = await getSupabaseServerClient();

  const [incidents, metrics, severity, rootCause, repeats, trend, daysSince] = await Promise.all([
    supabase.rpc('list_incidents_r2450'),
    supabase.rpc('list_metrics_r2450'),
    supabase.rpc('severity_breakdown_r2450'),
    supabase.rpc('root_cause_breakdown_r2450'),
    supabase.rpc('repeat_offenders_r2450'),
    supabase.rpc('monthly_incident_trend_r2450'),
    supabase.rpc('days_since_last_r2450'),
  ]);

  const incidentRows = (incidents.data ?? []) as any[];
  const metricRows = (metrics.data ?? []) as any[];
  const severityRows = (severity.data ?? []) as any[];
  const rootCauseRows = (rootCause.data ?? []) as any[];
  const repeatRows = (repeats.data ?? []) as any[];
  const trendRows = (trend.data ?? []) as any[];
  const daysRow = (daysSince.data ?? [])[0] as any;

  const incidentCols: Column<any>[] = [
    { key: 'incident_at', header: 'When', render: (r: any) => new Date(r.incident_at).toLocaleString() },
    { key: 'incident_kind', header: 'Kind', render: (r: any) => r.incident_kind },
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity },
    { key: 'root_cause_kind', header: 'Root cause', render: (r: any) => r.root_cause_kind },
    { key: 'near_miss', header: 'Near miss', render: (r: any) => (r.near_miss ? 'yes' : 'no') },
    { key: 'repeat_offender', header: 'Repeat', render: (r: any) => (r.repeat_offender ? 'yes' : 'no') },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'corrective_action_md', header: 'Corrective action', render: (r: any) => r.corrective_action_md },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes },
  ];

  const metricCols: Column<any>[] = [
    { key: 'period_start', header: 'Period start', render: (r: any) => String(r.period_start) },
    { key: 'period_end', header: 'Period end', render: (r: any) => String(r.period_end) },
    { key: 'incident_count', header: 'Incidents', render: (r: any) => String(r.incident_count) },
    { key: 'near_miss_count', header: 'Near miss', render: (r: any) => String(r.near_miss_count) },
    { key: 'severe_count', header: 'Severe', render: (r: any) => String(r.severe_count) },
    { key: 'repeat_offender_count', header: 'Repeats', render: (r: any) => String(r.repeat_offender_count) },
    { key: 'days_since_last_incident', header: 'Days since last', render: (r: any) => String(r.days_since_last_incident) },
    { key: 'top_root_cause', header: 'Top root cause', render: (r: any) => r.top_root_cause },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'action_plan_md', header: 'Action plan', render: (r: any) => r.action_plan_md },
  ];

  const severityCols: Column<any>[] = [
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity },
    { key: 'incident_count', header: 'Count', render: (r: any) => String(r.incident_count) },
    { key: 'open_count', header: 'Open', render: (r: any) => String(r.open_count) },
  ];

  const rootCauseCols: Column<any>[] = [
    { key: 'root_cause_kind', header: 'Root cause', render: (r: any) => r.root_cause_kind },
    { key: 'incident_count', header: 'Count', render: (r: any) => String(r.incident_count) },
    { key: 'severe_count', header: 'Severe', render: (r: any) => String(r.severe_count) },
  ];

  const repeatCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '-') },
    { key: 'incident_count', header: 'Incidents', render: (r: any) => String(r.incident_count) },
    { key: 'last_incident_at', header: 'Last incident', render: (r: any) => (r.last_incident_at ? new Date(r.last_incident_at).toLocaleString() : '-') },
    { key: 'worst_severity', header: 'Worst severity', render: (r: any) => r.worst_severity },
  ];

  const trendCols: Column<any>[] = [
    { key: 'period_start', header: 'Period', render: (r: any) => String(r.period_start) },
    { key: 'incident_count', header: 'Incidents', render: (r: any) => String(r.incident_count) },
    { key: 'near_miss_count', header: 'Near miss', render: (r: any) => String(r.near_miss_count) },
    { key: 'severe_count', header: 'Severe', render: (r: any) => String(r.severe_count) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 22, fontWeight: 700, marginBottom: 4 }}>Engineer Safety Incident Log</h1>
      <p style={{ color: '#555', marginBottom: 16 }}>
        Incidents x kind x severity x root cause x corrective action x near-miss x repeat offender. Round r2450.
      </p>

      <section style={{ marginBottom: 20, padding: 12, background: '#fff7ed', border: '1px solid #fed7aa', borderRadius: 6 }}>
        <strong>Days since last (non-near-miss) incident:</strong>{' '}
        {daysRow ? String(daysRow.days_since_last_incident) : '-'} ·{' '}
        last severity: {daysRow?.last_severity ?? '-'} · last kind: {daysRow?.last_kind ?? '-'}
      </section>

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '16px 0 8px' }}>Incident log</h2>
      <DataTable
        rows={incidentRows}
        columns={incidentCols}
        emptyMessage="No incidents logged."
        rowKey={(r: any, i: number) => String(r.id ?? i)}
      />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '24px 0 8px' }}>Monthly metrics</h2>
      <DataTable
        rows={metricRows}
        columns={metricCols}
        emptyMessage="No metric periods recorded."
        rowKey={(r: any, i: number) => String(r.id ?? i)}
      />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '24px 0 8px' }}>Severity breakdown</h2>
      <DataTable
        rows={severityRows}
        columns={severityCols}
        emptyMessage="No severity data."
        rowKey={(r: any, i: number) => String(r.severity ?? i)}
      />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '24px 0 8px' }}>Root cause breakdown</h2>
      <DataTable
        rows={rootCauseRows}
        columns={rootCauseCols}
        emptyMessage="No root cause data."
        rowKey={(r: any, i: number) => String(r.root_cause_kind ?? i)}
      />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '24px 0 8px' }}>Repeat offenders</h2>
      <DataTable
        rows={repeatRows}
        columns={repeatCols}
        emptyMessage="No repeat offenders."
        rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
      />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '24px 0 8px' }}>Monthly trend</h2>
      <DataTable
        rows={trendRows}
        columns={trendCols}
        emptyMessage="No trend data."
        rowKey={(r: any, i: number) => String(r.period_start ?? i)}
      />
    </main>
  );
}
