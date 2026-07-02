import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [triggers, recent, actions] = await Promise.all([
    sb.rpc('list_triggers_r2193'),
    sb.rpc('recent_triggers_r2193'),
    sb.rpc('recent_actions_r2193'),
  ]);

  const triggerRows: any[] = (triggers.data as any[]) ?? [];
  const recentRows: any[] = (recent.data as any[]) ?? [];
  const actionRows: any[] = (actions.data as any[]) ?? [];

  const triggerCols: Column<any>[] = [
    { key: 'trigger_event_label', header: 'Event', render: (r: any) => String(r.trigger_event_label ?? '') },
    { key: 'trigger_at', header: 'Triggered At', render: (r: any) => r.trigger_at ? new Date(r.trigger_at).toLocaleString() : '' },
    { key: 'total_converted_shares', header: 'Shares', render: (r: any) => Number(r.total_converted_shares ?? 0).toLocaleString() },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'trigger_event_label', header: 'Event', render: (r: any) => String(r.trigger_event_label ?? '') },
    { key: 'trigger_at', header: 'When', render: (r: any) => r.trigger_at ? new Date(r.trigger_at).toLocaleString() : '' },
    { key: 'total_converted_shares', header: 'Shares', render: (r: any) => Number(r.total_converted_shares ?? 0).toLocaleString() },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'taken_at', header: 'Taken At', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'shares_count', header: 'Shares', render: (r: any) => Number(r.shares_count ?? 0).toLocaleString() },
    { key: 'trigger_id', header: 'Trigger', render: (r: any) => String(r.trigger_id ?? '').slice(0, 8) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Investor Cap Table Conversion Trigger</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>Track preferred to common share conversion triggers and audit action log.</p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Triggers</h2>
        <DataTable rows={triggerRows} columns={triggerCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Triggers (90 days)</h2>
        <DataTable rows={recentRows} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Actions (60 days)</h2>
        <DataTable rows={actionRows} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
