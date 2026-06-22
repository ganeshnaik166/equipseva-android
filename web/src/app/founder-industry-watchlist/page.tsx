import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderIndustryWatchlistPage() {
  const sb = await getSupabaseServerClient();
  const [watchesRes, criticalRes, actionsRes] = await Promise.all([
    sb.rpc('list_watches_r2042'),
    sb.rpc('critical_watches_r2042'),
    sb.rpc('recent_actions_r2042', { p_limit: 50 }),
  ]);

  const watches: any[] = (watchesRes.data as any[]) ?? [];
  const critical: any[] = (criticalRes.data as any[]) ?? [];
  const actions: any[] = (actionsRes.data as any[]) ?? [];

  const watchCols: Column<any>[] = [
    { key: 'watch_label', header: 'Watch', render: (r: any) => r.watch_label },
    { key: 'watch_type', header: 'Type', render: (r: any) => r.watch_type },
    { key: 'importance', header: 'Importance', render: (r: any) => r.importance },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'captured_at', header: 'Captured', render: (r: any) => new Date(r.captured_at).toLocaleString() },
  ];

  const criticalCols: Column<any>[] = [
    { key: 'watch_label', header: 'Watch', render: (r: any) => r.watch_label },
    { key: 'watch_type', header: 'Type', render: (r: any) => r.watch_type },
    { key: 'importance', header: 'Importance', render: (r: any) => r.importance },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const actionCols: Column<any>[] = [
    { key: 'watch_id', header: 'Watch ID', render: (r: any) => String(r.watch_id).slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '' },
    { key: 'taken_at', header: 'Taken', render: (r: any) => new Date(r.taken_at).toLocaleString() },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md ?? '' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Founder Industry Watchlist</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Watchlist of industry events and threats spanning competitor, regulatory, technology, market, customer, and financial signals.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Critical and high importance (open)</h2>
        <DataTable rows={critical} columns={criticalCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All watches</h2>
        <DataTable rows={watches} columns={watchCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent action log</h2>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
