import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderDailyReadingLogPage() {
  const sb = await getSupabaseServerClient();

  const [itemsRes, actionsRes, byTypeRes, recentRes] = await Promise.all([
    sb.rpc('r2074_list_items'),
    sb.rpc('r2074_list_actions'),
    sb.rpc('r2074_by_type'),
    sb.rpc('r2074_recent_actions', { p_limit: 25 }),
  ]);

  const items: any[] = Array.isArray(itemsRes.data) ? itemsRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];
  const byType: any[] = Array.isArray(byTypeRes.data) ? byTypeRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const itemCols: Column<any>[] = [
    { key: 'item_label', header: 'Item', render: (r: any) => String(r.item_label ?? '') },
    { key: 'item_type', header: 'Type', render: (r: any) => String(r.item_type ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'started_at', header: 'Started', render: (r: any) => r.started_at ? new Date(r.started_at).toLocaleDateString() : '—' },
    { key: 'completed_at', header: 'Completed', render: (r: any) => r.completed_at ? new Date(r.completed_at).toLocaleDateString() : '—' },
    { key: 'source_url', header: 'Source', render: (r: any) => r.source_url ? <a href={String(r.source_url)} target="_blank" rel="noreferrer" className="text-blue-600 underline">link</a> : '—' },
    { key: 'takeaways_md', header: 'Takeaways', render: (r: any) => <span className="text-xs text-slate-700">{String(r.takeaways_md ?? '').slice(0, 120)}</span> },
  ];

  const actionCols: Column<any>[] = [
    { key: 'taken_at', header: 'When', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '—' },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'item_id', header: 'Item', render: (r: any) => <span className="font-mono text-xs">{String(r.item_id ?? '').slice(0, 8)}</span> },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '—') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => <span className="text-xs">{String(r.notes_md ?? '').slice(0, 100)}</span> },
  ];

  const byTypeCols: Column<any>[] = [
    { key: 'item_type', header: 'Type', render: (r: any) => String(r.item_type ?? '') },
    { key: 'total', header: 'Total', render: (r: any) => String(r.total ?? 0) },
    { key: 'reading', header: 'Reading', render: (r: any) => String(r.reading ?? 0) },
    { key: 'completed', header: 'Completed', render: (r: any) => String(r.completed ?? 0) },
    { key: 'abandoned', header: 'Abandoned', render: (r: any) => String(r.abandoned ?? 0) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'taken_at', header: 'When', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '—' },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '—') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => <span className="text-xs">{String(r.notes_md ?? '').slice(0, 80)}</span> },
  ];

  return (
    <main className="p-6 max-w-7xl mx-auto space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Founder Daily Reading Log</h1>
        <p className="text-sm text-slate-600">Books, articles, podcasts, newsletters, and videos the founder consumes. Track takeaways and lessons applied.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Items by type</h2>
        <DataTable rows={byType} columns={byTypeCols} rowKey={(r: any, i: number) => String(r.item_type ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent actions</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All items ({items.length})</h2>
        <DataTable rows={items} columns={itemCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All actions ({actions.length})</h2>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
