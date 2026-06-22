import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [packsRes, recentPacksRes, recentActionsRes] = await Promise.all([
    sb.rpc('list_packs_r2009'),
    sb.rpc('recent_packs_r2009'),
    sb.rpc('recent_actions_r2009'),
  ]);

  const packs: any[] = Array.isArray(packsRes.data) ? packsRes.data : [];
  const recentPacks: any[] = Array.isArray(recentPacksRes.data) ? recentPacksRes.data : [];
  const recentActions: any[] = Array.isArray(recentActionsRes.data) ? recentActionsRes.data : [];

  const packCols: Column<any>[] = [
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'generated_at', header: 'Generated', render: (r: any) => r.generated_at ? new Date(r.generated_at).toLocaleString() : '' },
    { key: 'sent_at', header: 'Sent', render: (r: any) => r.sent_at ? new Date(r.sent_at).toLocaleString() : '' },
    { key: 'summary', header: 'Summary', render: (r: any) => String(r.pack_summary_md ?? '').slice(0, 80) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'created_at', header: 'Created', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleString() : '' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken At', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 80) },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Investor 8x8 Reporting Pack</h1>
        <p className="text-sm text-gray-600">Generate, send, and track acknowledgements for the 8x8 investor reporting cadence.</p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-2">All Packs</h2>
        <DataTable rows={packs} columns={packCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Recent Packs</h2>
        <DataTable rows={recentPacks} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Recent Actions</h2>
        <DataTable rows={recentActions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
