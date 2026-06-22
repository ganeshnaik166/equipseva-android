import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [velRes, fastRes, actRes] = await Promise.all([
    sb.rpc('list_velocities_r2130'),
    sb.rpc('fast_velocity_weeks_r2130'),
    sb.rpc('recent_velocity_actions_r2130'),
  ]);

  const velocities: any[] = Array.isArray(velRes.data) ? velRes.data : [];
  const fastWeeks: any[] = Array.isArray(fastRes.data) ? fastRes.data : [];
  const actions: any[] = Array.isArray(actRes.data) ? actRes.data : [];

  const velCols: Column<any>[] = [
    { key: 'week_label', header: 'Week', render: (r: any) => String(r.week_label ?? '') },
    { key: 'decisions_made', header: 'Decisions', render: (r: any) => String(r.decisions_made ?? 0) },
    { key: 'avg_decision_hours', header: 'Avg hours', render: (r: any) => String(r.avg_decision_hours ?? 0) },
    { key: 'fastest_decision_hours', header: 'Fastest hours', render: (r: any) => String(r.fastest_decision_hours ?? 0) },
    { key: 'slowest_decision_hours', header: 'Slowest hours', render: (r: any) => String(r.slowest_decision_hours ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const fastCols: Column<any>[] = [
    { key: 'week_label', header: 'Week', render: (r: any) => String(r.week_label ?? '') },
    { key: 'decisions_made', header: 'Decisions', render: (r: any) => String(r.decisions_made ?? 0) },
    { key: 'avg_decision_hours', header: 'Avg hours', render: (r: any) => String(r.avg_decision_hours ?? 0) },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const actCols: Column<any>[] = [
    { key: 'velocity_id', header: 'Velocity', render: (r: any) => String(r.velocity_id ?? '').slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
  ];

  return (
    <main style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Founder Decision Velocity Tracker</h1>
        <p style={{ color: '#666', marginTop: 4 }}>Track how quickly founder decisions move week over week.</p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All velocity weeks</h2>
        <DataTable rows={velocities} columns={velCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Fast weeks</h2>
        <DataTable rows={fastWeeks} columns={fastCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent actions</h2>
        <DataTable rows={actions} columns={actCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
