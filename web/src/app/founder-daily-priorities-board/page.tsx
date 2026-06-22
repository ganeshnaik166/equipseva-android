import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const { data: priorities } = await sb.rpc('list_priorities_r2022');
  const { data: today } = await sb.rpc('today_priorities_r2022');
  const { data: recent } = await sb.rpc('recent_actions_r2022');

  const priorityRows: any[] = Array.isArray(priorities) ? priorities : [];
  const todayRows: any[] = Array.isArray(today) ? today : [];
  const recentRows: any[] = Array.isArray(recent) ? recent : [];

  const priorityCols: Column<any>[] = [
    { key: 'priority_label', header: 'Label', render: (r: any) => String(r.priority_label ?? '') },
    { key: 'priority_level', header: 'Level', render: (r: any) => String(r.priority_level ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'scheduled_for', header: 'Scheduled', render: (r: any) => String(r.scheduled_for ?? '') },
    { key: 'completed_at', header: 'Completed', render: (r: any) => r.completed_at ? String(r.completed_at).slice(0, 16) : '' },
    { key: 'created_at', header: 'Created', render: (r: any) => r.created_at ? String(r.created_at).slice(0, 16) : '' },
  ];

  const todayCols: Column<any>[] = [
    { key: 'priority_label', header: 'Label', render: (r: any) => String(r.priority_label ?? '') },
    { key: 'priority_level', header: 'Level', render: (r: any) => String(r.priority_level ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'created_at', header: 'Created', render: (r: any) => r.created_at ? String(r.created_at).slice(0, 16) : '' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'priority_id', header: 'Priority', render: (r: any) => String(r.priority_id ?? '').slice(0, 8) },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? String(r.taken_at).slice(0, 16) : '' },
  ];

  return (
    <main style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Founder Daily Priorities Board</h1>
        <p style={{ color: '#555', marginTop: 4 }}>Track daily founder priorities and the action log behind each one.</p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Today</h2>
        <DataTable rows={todayRows} columns={todayCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All Priorities</h2>
        <DataTable rows={priorityRows} columns={priorityCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent Actions</h2>
        <DataTable rows={recentRows} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
