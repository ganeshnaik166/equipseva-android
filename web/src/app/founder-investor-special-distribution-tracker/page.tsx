import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [distRes, recentRes, actionsRes] = await Promise.all([
    sb.rpc('list_distributions_r2145'),
    sb.rpc('recent_special_r2145'),
    sb.rpc('recent_actions_r2145'),
  ]);

  const distributions: any[] = Array.isArray(distRes.data) ? distRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];

  const distCols: Column<any>[] = [
    { key: 'label', header: 'Label', render: (r: any) => String(r.distribution_label ?? '') },
    { key: 'amount', header: 'Amount (rupees)', render: (r: any) => String(r.amount_rupees ?? 0) },
    { key: 'reason', header: 'Reason', render: (r: any) => String(r.reason ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'declared', header: 'Declared at', render: (r: any) => r.declared_at ? new Date(r.declared_at).toLocaleString() : 'pending' },
    { key: 'paid', header: 'Paid at', render: (r: any) => r.paid_at ? new Date(r.paid_at).toLocaleString() : 'pending' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'label', header: 'Label', render: (r: any) => String(r.distribution_label ?? '') },
    { key: 'amount', header: 'Amount (rupees)', render: (r: any) => String(r.amount_rupees ?? 0) },
    { key: 'reason', header: 'Reason', render: (r: any) => String(r.reason ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'created', header: 'Created at', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleString() : '' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action', header: 'Action type', render: (r: any) => String(r.action_type ?? '') },
    { key: 'taken', header: 'Taken at', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'amount', header: 'Amount (rupees)', render: (r: any) => r.amount_rupees == null ? '' : String(r.amount_rupees) },
    { key: 'dist_id', header: 'Distribution id', render: (r: any) => String(r.distribution_id ?? '').slice(0, 8) },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: '1200px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '8px' }}>Investor Special Distribution Tracker</h1>
      <p style={{ color: '#555', marginBottom: '24px' }}>
        Track one-off distributions covering liquidity events, buybacks, extraordinary dividends and legal settlements.
      </p>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>All distributions</h2>
        <DataTable rows={distributions} columns={distCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Recent special distributions (last 90 days)</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Recent actions (last 60 days)</h2>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
