import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [idlesRes, currentRes, recentRes] = await Promise.all([
    sb.rpc('list_idles_r1964', { p_limit: 100 }),
    sb.rpc('current_idles_r1964'),
    sb.rpc('recent_actions_r1964', { p_limit: 50 }),
  ]);

  const idles = (idlesRes.data ?? []) as any[];
  const current = (currentRes.data ?? []) as any[];
  const recent = (recentRes.data ?? []) as any[];

  const idlesCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'idle_reason', header: 'Reason', render: (r: any) => String(r.idle_reason ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'idle_start_at', header: 'Start', render: (r: any) => r.idle_start_at ? new Date(r.idle_start_at).toLocaleString() : '' },
    { key: 'idle_end_at', header: 'End', render: (r: any) => r.idle_end_at ? new Date(r.idle_end_at).toLocaleString() : '-' },
    { key: 'idle_duration_minutes', header: 'Minutes', render: (r: any) => String(r.idle_duration_minutes ?? '-') },
  ];

  const currentCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'idle_reason', header: 'Reason', render: (r: any) => String(r.idle_reason ?? '') },
    { key: 'idle_start_at', header: 'Since', render: (r: any) => r.idle_start_at ? new Date(r.idle_start_at).toLocaleString() : '' },
    { key: 'minutes_idle', header: 'Minutes Idle', render: (r: any) => String(r.minutes_idle ?? 0) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'idle_id', header: 'Idle', render: (r: any) => String(r.idle_id ?? '').slice(0, 8) },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'When', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Idle Time Tracker</h1>
        <p className="text-sm text-gray-600">Track engineer idle time between jobs and actions taken to resolve it.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Currently Idle ({current.length})</h2>
        <p className="text-xs text-gray-500 mb-2">Engineers with active idle status. Watch for minutes idle above 60.</p>
        <DataTable rows={current} columns={currentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Idle Periods ({idles.length})</h2>
        <p className="text-xs text-gray-500 mb-2">Recent idle periods ordered newest first. Closed periods show end time and total minutes.</p>
        <DataTable rows={idles} columns={idlesCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Actions ({recent.length})</h2>
        <p className="text-xs text-gray-500 mb-2">Last 50 actions taken on idle periods such as job assigned and training started.</p>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
