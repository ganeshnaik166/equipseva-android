import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderCustomerEmergencyEscalationRunbookPage() {
  const supabase = await getSupabaseServerClient();

  const [incidents, lessons, severity, response, kinds, monthly, owners] = await Promise.all([
    supabase.rpc('list_incidents_r2496'),
    supabase.rpc('list_lessons_r2496'),
    supabase.rpc('top_severity_focus_r2496'),
    supabase.rpc('response_time_summary_r2496'),
    supabase.rpc('lesson_kind_breakdown_r2496'),
    supabase.rpc('monthly_incident_trend_r2496'),
    supabase.rpc('owner_load_r2496'),
  ]);

  const incidentRows = (incidents.data ?? []) as any[];
  const lessonRows = (lessons.data ?? []) as any[];
  const severityRows = (severity.data ?? []) as any[];
  const responseRows = (response.data ?? []) as any[];
  const kindRows = (kinds.data ?? []) as any[];
  const monthlyRows = (monthly.data ?? []) as any[];
  const ownerRows = (owners.data ?? []) as any[];

  const incidentCols: Column<any>[] = [
    { key: 'incident_at', header: 'When', render: (r: any) => String(r.incident_at ?? '').replace('T', ' ').slice(0, 16) },
    { key: 'severity', header: 'Severity', render: (r: any) => String(r.severity) },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label ?? '' },
    { key: 'escalation_path_md', header: 'Escalation path', render: (r: any) => r.escalation_path_md ?? '' },
    { key: 'response_minutes', header: 'Response (min)', render: (r: any) => r.response_minutes != null ? String(r.response_minutes) : '' },
    { key: 'resolution_minutes', header: 'Resolution (min)', render: (r: any) => r.resolution_minutes != null ? String(r.resolution_minutes) : '' },
    { key: 'customer_satisfaction', header: 'CSAT', render: (r: any) => r.customer_satisfaction != null ? `${r.customer_satisfaction}/10` : '' },
    { key: 'escalation_owner_email', header: 'Owner', render: (r: any) => r.escalation_owner_email ?? '' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status) },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const lessonCols: Column<any>[] = [
    { key: 'lesson_kind', header: 'Kind', render: (r: any) => String(r.lesson_kind) },
    { key: 'lesson_md', header: 'Lesson', render: (r: any) => r.lesson_md ?? '' },
    { key: 'action_taken_md', header: 'Action taken', render: (r: any) => r.action_taken_md ?? '' },
    { key: 'action_owner_email', header: 'Owner', render: (r: any) => r.action_owner_email ?? '' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status) },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const severityCols: Column<any>[] = [
    { key: 'severity', header: 'Severity', render: (r: any) => String(r.severity) },
    { key: 'incident_count', header: 'Incidents', render: (r: any) => String(r.incident_count) },
    { key: 'avg_response', header: 'Avg response (min)', render: (r: any) => String(r.avg_response ?? '') },
    { key: 'avg_resolution', header: 'Avg resolution (min)', render: (r: any) => String(r.avg_resolution ?? '') },
    { key: 'avg_csat', header: 'Avg CSAT', render: (r: any) => String(r.avg_csat ?? '') },
    { key: 'open_count', header: 'Open', render: (r: any) => String(r.open_count) },
  ];

  const responseCols: Column<any>[] = [
    { key: 'metric', header: 'Metric', render: (r: any) => String(r.metric) },
    { key: 'value', header: 'Value', render: (r: any) => String(r.value) },
    { key: 'detail', header: 'Detail', render: (r: any) => String(r.detail) },
  ];

  const kindCols: Column<any>[] = [
    { key: 'lesson_kind', header: 'Lesson kind', render: (r: any) => String(r.lesson_kind) },
    { key: 'lesson_count', header: 'Total', render: (r: any) => String(r.lesson_count) },
    { key: 'open_count', header: 'Open', render: (r: any) => String(r.open_count) },
    { key: 'done_count', header: 'Done', render: (r: any) => String(r.done_count) },
  ];

  const monthlyCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => String(r.month_start) },
    { key: 'incident_count', header: 'Incidents', render: (r: any) => String(r.incident_count) },
    { key: 'code_red_count', header: 'Code red', render: (r: any) => String(r.code_red_count) },
    { key: 'avg_response', header: 'Avg response (min)', render: (r: any) => String(r.avg_response ?? '') },
    { key: 'avg_resolution', header: 'Avg resolution (min)', render: (r: any) => String(r.avg_resolution ?? '') },
    { key: 'avg_csat', header: 'Avg CSAT', render: (r: any) => String(r.avg_csat ?? '') },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => String(r.owner_email ?? '') },
    { key: 'incident_owned', header: 'Incidents owned', render: (r: any) => String(r.incident_owned) },
    { key: 'lessons_owned', header: 'Lessons owned', render: (r: any) => String(r.lessons_owned) },
    { key: 'open_actions', header: 'Open actions', render: (r: any) => String(r.open_actions) },
  ];

  return (
    <main style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 32 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Customer emergency escalation runbook</h1>
        <p style={{ color: '#555', marginTop: 4 }}>
          Incident & severity & escalation path & response time & resolution => lessons captured.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Response time summary</h2>
        <DataTable
          rows={responseRows}
          columns={responseCols}
          emptyMessage="No response data yet."
          rowKey={(r: any, i: number) => String(r.metric ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top severity focus</h2>
        <DataTable
          rows={severityRows}
          columns={severityCols}
          emptyMessage="No severity rollup yet."
          rowKey={(r: any, i: number) => String(r.severity ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Incidents log</h2>
        <DataTable
          rows={incidentRows}
          columns={incidentCols}
          emptyMessage="No incidents logged yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Runbook lessons & actions</h2>
        <DataTable
          rows={lessonRows}
          columns={lessonCols}
          emptyMessage="No lessons captured yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Lesson kind breakdown</h2>
        <DataTable
          rows={kindRows}
          columns={kindCols}
          emptyMessage="No lesson kinds yet."
          rowKey={(r: any, i: number) => String(r.lesson_kind ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Monthly incident trend</h2>
        <DataTable
          rows={monthlyRows}
          columns={monthlyCols}
          emptyMessage="No monthly trend yet."
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Owner load</h2>
        <DataTable
          rows={ownerRows}
          columns={ownerCols}
          emptyMessage="No owners assigned yet."
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>
    </main>
  );
}
