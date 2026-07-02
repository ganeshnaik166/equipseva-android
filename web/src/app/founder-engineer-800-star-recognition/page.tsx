import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [recRes, actRes, recentRecRes, recentActRes] = await Promise.all([
    sb.rpc('list_recognitions_r2188', { p_limit: 200 }),
    sb.rpc('list_actions_r2188', { p_recognition_id: null, p_limit: 200 }),
    sb.rpc('recent_recognitions_r2188', { p_days: 30 }),
    sb.rpc('recent_actions_r2188', { p_days: 30 }),
  ]);

  const recognitions: any[] = Array.isArray(recRes.data) ? recRes.data : [];
  const actions: any[] = Array.isArray(actRes.data) ? actRes.data : [];
  const recentRec: any[] = Array.isArray(recentRecRes.data) ? recentRecRes.data : [];
  const recentAct: any[] = Array.isArray(recentActRes.data) ? recentActRes.data : [];

  const recCols: Column<any>[] = [
    { key: 'id', header: 'ID', render: (r: any) => <span className="font-mono text-xs">{String(r.id ?? '').slice(0, 8)}</span> },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => <span className="font-mono text-xs">{String(r.engineer_user_id ?? '').slice(0, 8)}</span> },
    { key: 'recognition_type', header: 'Type', render: (r: any) => <span>{String(r.recognition_type ?? '')}</span> },
    { key: 'recognition_md', header: 'Note', render: (r: any) => <span className="text-sm">{String(r.recognition_md ?? '').slice(0, 80)}</span> },
    { key: 'awarded_at', header: 'Awarded', render: (r: any) => <span>{r.awarded_at ? new Date(r.awarded_at).toLocaleString() : ''}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span>{String(r.status ?? '')}</span> },
  ];

  const actCols: Column<any>[] = [
    { key: 'id', header: 'ID', render: (r: any) => <span className="font-mono text-xs">{String(r.id ?? '').slice(0, 8)}</span> },
    { key: 'recognition_id', header: 'Recognition', render: (r: any) => <span className="font-mono text-xs">{String(r.recognition_id ?? '').slice(0, 8)}</span> },
    { key: 'action_type', header: 'Action', render: (r: any) => <span>{String(r.action_type ?? '')}</span> },
    { key: 'taken_at', header: 'Taken', render: (r: any) => <span>{r.taken_at ? new Date(r.taken_at).toLocaleString() : ''}</span> },
    { key: 'by_email', header: 'By', render: (r: any) => <span>{String(r.by_email ?? '')}</span> },
    { key: 'notes_md', header: 'Notes', render: (r: any) => <span className="text-sm">{String(r.notes_md ?? '').slice(0, 80)}</span> },
  ];

  const recentRecCols: Column<any>[] = [
    { key: 'id', header: 'ID', render: (r: any) => <span className="font-mono text-xs">{String(r.id ?? '').slice(0, 8)}</span> },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => <span className="font-mono text-xs">{String(r.engineer_user_id ?? '').slice(0, 8)}</span> },
    { key: 'recognition_type', header: 'Type', render: (r: any) => <span>{String(r.recognition_type ?? '')}</span> },
    { key: 'awarded_at', header: 'Awarded', render: (r: any) => <span>{r.awarded_at ? new Date(r.awarded_at).toLocaleString() : ''}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span>{String(r.status ?? '')}</span> },
  ];

  const recentActCols: Column<any>[] = [
    { key: 'id', header: 'ID', render: (r: any) => <span className="font-mono text-xs">{String(r.id ?? '').slice(0, 8)}</span> },
    { key: 'action_type', header: 'Action', render: (r: any) => <span>{String(r.action_type ?? '')}</span> },
    { key: 'taken_at', header: 'Taken', render: (r: any) => <span>{r.taken_at ? new Date(r.taken_at).toLocaleString() : ''}</span> },
    { key: 'by_email', header: 'By', render: (r: any) => <span>{String(r.by_email ?? '')}</span> },
  ];

  return (
    <div className="p-6 space-y-8 max-w-7xl mx-auto">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Engineer 800-Star Recognition</h1>
        <p className="text-sm text-gray-600">800 HEAVY milestone engineer recognition library and action log.</p>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-3 pt-2">
          <div className="rounded border p-3"><div className="text-xs text-gray-500">Total recognitions</div><div className="text-xl font-semibold">{recognitions.length}</div></div>
          <div className="rounded border p-3"><div className="text-xs text-gray-500">Total actions</div><div className="text-xl font-semibold">{actions.length}</div></div>
          <div className="rounded border p-3"><div className="text-xs text-gray-500">Last 30d recognitions</div><div className="text-xl font-semibold">{recentRec.length}</div></div>
        </div>
      </header>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">All recognitions</h2>
        <DataTable rows={recognitions} columns={recCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Action log</h2>
        <DataTable rows={actions} columns={actCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Recent recognitions (30d)</h2>
        <DataTable rows={recentRec} columns={recentRecCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Recent actions (30d)</h2>
        <DataTable rows={recentAct} columns={recentActCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
