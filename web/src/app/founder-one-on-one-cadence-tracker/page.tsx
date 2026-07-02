import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [sessionsRes, actionsRes, topRes, aggRes] = await Promise.all([
    sb.rpc('list_one_on_one_sessions_r2221'),
    sb.rpc('recent_actions_one_on_one_r2221'),
    sb.rpc('top_one_on_one_reports_r2221'),
    sb.rpc('aggregate_one_on_one_r2221'),
  ]);

  const sessions: any[] = Array.isArray(sessionsRes.data) ? sessionsRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];
  const top: any[] = Array.isArray(topRes.data) ? topRes.data : [];
  const agg: any = Array.isArray(aggRes.data) && aggRes.data.length > 0 ? aggRes.data[0] : {};

  const sessionCols: Column<any>[] = [
    { key: 'report_name', header: 'Report', render: (r: any) => String(r.report_name ?? '') },
    { key: 'report_role', header: 'Role', render: (r: any) => String(r.report_role ?? '') },
    { key: 'scheduled_at', header: 'Scheduled', render: (r: any) => r.scheduled_at ? new Date(r.scheduled_at).toLocaleString() : '' },
    { key: 'duration_minutes', header: 'Mins', render: (r: any) => String(r.duration_minutes ?? '') },
    { key: 'cadence', header: 'Cadence', render: (r: any) => String(r.cadence ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'mood', header: 'Mood', render: (r: any) => String(r.mood ?? '') },
    { key: 'agenda', header: 'Agenda', render: (r: any) => String(r.agenda ?? '').slice(0, 80) },
  ];

  const actionCols: Column<any>[] = [
    { key: 'report_name', header: 'Report', render: (r: any) => String(r.report_name ?? '') },
    { key: 'action_text', header: 'Action', render: (r: any) => String(r.action_text ?? '') },
    { key: 'owner', header: 'Owner', render: (r: any) => String(r.owner ?? '') },
    { key: 'due_date', header: 'Due', render: (r: any) => String(r.due_date ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'carried_over_count', header: 'Carried', render: (r: any) => String(r.carried_over_count ?? 0) },
    { key: 'created_at', header: 'Logged', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleString() : '' },
  ];

  const topCols: Column<any>[] = [
    { key: 'report_name', header: 'Report', render: (r: any) => String(r.report_name ?? '') },
    { key: 'sessions_count', header: 'Sessions', render: (r: any) => String(r.sessions_count ?? 0) },
    { key: 'completed_count', header: 'Completed', render: (r: any) => String(r.completed_count ?? 0) },
    { key: 'open_actions', header: 'Open actions', render: (r: any) => String(r.open_actions ?? 0) },
    { key: 'last_session', header: 'Last', render: (r: any) => r.last_session ? new Date(r.last_session).toLocaleString() : '' },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Founder one-on-one cadence tracker</h1>
        <p style={{ color: '#555', marginTop: 4 }}>
          Schedule 1:1s with each direct report — agenda, action items & follow-up between sessions.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12 }}>
        <Stat label="Total sessions" value={agg.total_sessions ?? 0} />
        <Stat label="Upcoming" value={agg.scheduled_upcoming ?? 0} />
        <Stat label="Completed 30d" value={agg.completed_last_30 ?? 0} />
        <Stat label="No-show 30d" value={agg.no_show_last_30 ?? 0} />
        <Stat label="Open actions" value={agg.open_actions ?? 0} />
        <Stat label="Carried-over" value={agg.carried_over_actions ?? 0} />
        <Stat label="Unique reports" value={agg.unique_reports ?? 0} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Sessions</h2>
        <DataTable rows={sessions} columns={sessionCols} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Action items & follow-ups</h2>
        <DataTable rows={actions} columns={actionCols} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top reports by cadence</h2>
        <DataTable rows={top} columns={topCols} rowKey={(_, i) => String(i)} />
      </section>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: number | string }) {
  return (
    <div style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 12 }}>
      <div style={{ fontSize: 12, color: '#666' }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700 }}>{String(value)}</div>
    </div>
  );
}
