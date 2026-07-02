import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [schedulesRes, upcomingRes, recentRes] = await Promise.all([
    sb.rpc('list_schedules_r2077'),
    sb.rpc('upcoming_r2077'),
    sb.rpc('recent_actions_r2077'),
  ]);

  const schedules: any[] = (schedulesRes.data as any[]) ?? [];
  const upcoming: any[] = (upcomingRes.data as any[]) ?? [];
  const recent: any[] = (recentRes.data as any[]) ?? [];

  const scheduleCols: Column<any>[] = [
    { key: 'scheduled_date', header: 'Scheduled', render: (r: any) => String(r.scheduled_date ?? '') },
    { key: 'reconciliation_type', header: 'Type', render: (r: any) => String(r.reconciliation_type ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'completed_at', header: 'Completed', render: (r: any) => r.completed_at ? new Date(r.completed_at).toLocaleString() : '-' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
  ];

  const upcomingCols: Column<any>[] = [
    { key: 'scheduled_date', header: 'Scheduled', render: (r: any) => String(r.scheduled_date ?? '') },
    { key: 'reconciliation_type', header: 'Type', render: (r: any) => String(r.reconciliation_type ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
  ];

  const recentCols: Column<any>[] = [
    { key: 'taken_at', header: 'Taken At', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '-' },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'schedule_id', header: 'Schedule', render: (r: any) => String(r.schedule_id ?? '').slice(0, 8) },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
  ];

  return (
    <main style={{ padding: '1.5rem', maxWidth: '1200px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', fontWeight: 700, marginBottom: '0.5rem' }}>
        Investor Cap Table Reconciliation Schedule
      </h1>
      <p style={{ color: '#666', marginBottom: '1.5rem' }}>
        Schedule and track cap table reconciliations across monthly, quarterly, annual, incident, and triggered cadences.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Upcoming</h2>
        <DataTable
          rows={upcoming}
          columns={upcomingCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>All Schedules</h2>
        <DataTable
          rows={schedules}
          columns={scheduleCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Recent Actions</h2>
        <DataTable
          rows={recent}
          columns={recentCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
