import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [classesRes, actionsRes, activeRes, recentRes] = await Promise.all([
    sb.rpc('list_classes_r2173'),
    sb.rpc('list_actions_r2173'),
    sb.rpc('active_classes_r2173'),
    sb.rpc('recent_actions_r2173'),
  ]);

  const classes: any[] = Array.isArray(classesRes.data) ? classesRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];
  const active: any[] = Array.isArray(activeRes.data) ? activeRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const totalShares = active.reduce((s, r) => s + Number(r.total_shares || 0), 0);

  const classCols: Column<any>[] = [
    { key: 'share_class_label', header: 'Class', render: (r: any) => String(r.share_class_label ?? '') },
    { key: 'total_shares', header: 'Shares', render: (r: any) => String(r.total_shares ?? 0) },
    { key: 'conversion_ratio', header: 'Ratio', render: (r: any) => String(r.conversion_ratio ?? 1) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'shares_change', header: 'Shares Change', render: (r: any) => String(r.shares_change ?? 0) },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken At', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'class_id', header: 'Class', render: (r: any) => String(r.class_id ?? '').slice(0, 8) },
  ];

  const activeCols: Column<any>[] = [
    { key: 'share_class_label', header: 'Class', render: (r: any) => String(r.share_class_label ?? '') },
    { key: 'total_shares', header: 'Shares', render: (r: any) => String(r.total_shares ?? 0) },
    { key: 'conversion_ratio', header: 'Ratio', render: (r: any) => String(r.conversion_ratio ?? 1) },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'shares_change', header: 'Shares', render: (r: any) => String(r.shares_change ?? 0) },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken At', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: '1200px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '8px' }}>
        Investor Cap Table Share Class Tracker
      </h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Track share classes across the cap table. Round r2173.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '16px', marginBottom: '24px' }}>
        <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Active Classes</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{active.length}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Total Active Shares</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{totalShares.toLocaleString()}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Recent Actions (30d)</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{recent.length}</div>
        </div>
      </div>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>All Share Classes</h2>
        <DataTable rows={classes} columns={classCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Active Classes</h2>
        <DataTable rows={active} columns={activeCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Recent Actions (last 30 days)</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Full Action Log</h2>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
