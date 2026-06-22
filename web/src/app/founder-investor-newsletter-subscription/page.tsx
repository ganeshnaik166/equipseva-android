import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [subsRes, actionsRes, activeRes, recentRes] = await Promise.all([
    sb.rpc('list_subscriptions_r2049'),
    sb.rpc('list_actions_r2049'),
    sb.rpc('active_subscribers_r2049'),
    sb.rpc('recent_actions_r2049', { p_limit: 50 }),
  ]);

  const subs: any[] = Array.isArray(subsRes.data) ? subsRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];
  const active: any[] = Array.isArray(activeRes.data) ? activeRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const subColumns: Column<any>[] = [
    { key: 'id', header: 'ID', render: (r: any) => String(r.id ?? '').slice(0, 8) },
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id ?? '').slice(0, 8) },
    { key: 'subscription_type', header: 'Cadence', render: (r: any) => String(r.subscription_type ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'last_sent_at', header: 'Last Sent', render: (r: any) => r.last_sent_at ? new Date(r.last_sent_at).toLocaleString() : '-' },
    { key: 'subscribed_at', header: 'Subscribed', render: (r: any) => r.subscribed_at ? new Date(r.subscribed_at).toLocaleString() : '-' },
  ];

  const activeColumns: Column<any>[] = [
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id ?? '').slice(0, 8) },
    { key: 'subscription_type', header: 'Cadence', render: (r: any) => String(r.subscription_type ?? '') },
    { key: 'last_sent_at', header: 'Last Sent', render: (r: any) => r.last_sent_at ? new Date(r.last_sent_at).toLocaleString() : '-' },
    { key: 'subscribed_at', header: 'Subscribed', render: (r: any) => r.subscribed_at ? new Date(r.subscribed_at).toLocaleString() : '-' },
  ];

  const actionColumns: Column<any>[] = [
    { key: 'id', header: 'ID', render: (r: any) => String(r.id ?? '').slice(0, 8) },
    { key: 'subscription_id', header: 'Subscription', render: (r: any) => String(r.subscription_id ?? '').slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '-' },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '-') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '-') },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Investor Newsletter Subscription</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Manage newsletter subscriptions per investor. Track cadence, status, and action history.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Subscriptions ({subs.length})</h2>
        <DataTable rows={subs} columns={subColumns} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Active Subscribers ({active.length})</h2>
        <DataTable rows={active} columns={activeColumns} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Actions ({recent.length})</h2>
        <DataTable rows={recent} columns={actionColumns} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Full Action Log ({actions.length})</h2>
        <DataTable rows={actions} columns={actionColumns} rowKey={(r, i) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
