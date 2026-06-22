import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const { data: amendments } = await sb.rpc('list_amendments_r2157');
  const { data: recentAmend } = await sb.rpc('recent_amendments_r2157', { p_limit: 20 });
  const { data: recentActions } = await sb.rpc('recent_actions_r2157', { p_limit: 20 });

  const amendmentRows: any[] = Array.isArray(amendments) ? amendments : [];
  const recentAmendRows: any[] = Array.isArray(recentAmend) ? recentAmend : [];
  const recentActionsRows: any[] = Array.isArray(recentActions) ? recentActions : [];

  const amendmentCols: Column<any>[] = [
    { key: 'original_ts_label', header: 'Original TS', render: (r: any) => String(r.original_ts_label ?? '') },
    { key: 'amendment_label', header: 'Amendment', render: (r: any) => String(r.amendment_label ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'signed_at', header: 'Signed At', render: (r: any) => r.signed_at ? new Date(r.signed_at).toLocaleString() : 'unsigned' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const recentAmendCols: Column<any>[] = [
    { key: 'original_ts_label', header: 'Original TS', render: (r: any) => String(r.original_ts_label ?? '') },
    { key: 'amendment_label', header: 'Amendment', render: (r: any) => String(r.amendment_label ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'signed_at', header: 'Signed', render: (r: any) => r.signed_at ? new Date(r.signed_at).toLocaleString() : 'unsigned' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'amendment_id', header: 'Amendment ID', render: (r: any) => String(r.amendment_id ?? '').slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken At', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 80) },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Investor Term Sheet Amendment Tracker</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track amendments to existing term sheets. Statuses include active, superseded, disputed, and closed.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Amendments</h2>
        <DataTable rows={amendmentRows} columns={amendmentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Amendments</h2>
        <DataTable rows={recentAmendRows} columns={recentAmendCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Action Log</h2>
        <DataTable rows={recentActionsRows} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}