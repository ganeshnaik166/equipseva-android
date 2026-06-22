import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [rightsRes, expiringRes, recentRes] = await Promise.all([
    sb.rpc('list_tag_along_rights_r2109', { p_limit: 200 }),
    sb.rpc('expiring_tag_along_rights_r2109', { p_days: 30 }),
    sb.rpc('recent_tag_along_actions_r2109', { p_limit: 50 }),
  ]);

  const rights: any[] = Array.isArray(rightsRes.data) ? rightsRes.data : [];
  const expiring: any[] = Array.isArray(expiringRes.data) ? expiringRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const rightsCols: Column<any>[] = [
    { key: 'tag_along_label', header: 'Label', render: (r: any) => String(r.tag_along_label ?? '') },
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id ?? '').slice(0, 8) },
    { key: 'max_tag_along_shares', header: 'Max Shares', render: (r: any) => String(r.max_tag_along_shares ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'expires_at', header: 'Expires', render: (r: any) => r.expires_at ? new Date(r.expires_at).toLocaleDateString() : 'none' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleDateString() : '' },
  ];

  const expiringCols: Column<any>[] = [
    { key: 'tag_along_label', header: 'Label', render: (r: any) => String(r.tag_along_label ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'expires_at', header: 'Expires', render: (r: any) => r.expires_at ? new Date(r.expires_at).toLocaleDateString() : 'none' },
    { key: 'max_tag_along_shares', header: 'Max Shares', render: (r: any) => String(r.max_tag_along_shares ?? 0) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'right_id', header: 'Right', render: (r: any) => String(r.right_id ?? '').slice(0, 8) },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'shares_tagged', header: 'Shares', render: (r: any) => String(r.shares_tagged ?? 0) },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
  ];

  const activeCount = rights.filter((r: any) => r.status === 'active').length;
  const exercisedCount = rights.filter((r: any) => r.status === 'exercised').length;
  const waivedCount = rights.filter((r: any) => r.status === 'waived').length;

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Investor Tag-Along Right Tracker</h1>
      <p style={{ color: '#555', marginBottom: 16 }}>
        Track investor tag-along rights, exercises, waivers, and expirations.
      </p>

      <section style={{ marginBottom: 24, display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12 }}>
        <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total Rights</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{rights.length}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Active</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{activeCount}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Exercised</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{exercisedCount}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Waived</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{waivedCount}</div>
        </div>
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All Tag-Along Rights</h2>
        <DataTable rows={rights} columns={rightsCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Expiring Within 30 Days</h2>
        <DataTable rows={expiring} columns={expiringCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent Actions</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
