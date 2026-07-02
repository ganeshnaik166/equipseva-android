import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderInvestorRofrTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [rofrsRes, actionsRes, expiringRes, recentRes] = await Promise.all([
    sb.rpc('list_investor_rofrs_r2133'),
    sb.rpc('list_investor_rofr_actions_r2133'),
    sb.rpc('list_investor_rofr_expiring_soon_r2133'),
    sb.rpc('list_investor_rofr_recent_actions_r2133'),
  ]);

  const rofrs: any[] = Array.isArray(rofrsRes.data) ? rofrsRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];
  const expiring: any[] = Array.isArray(expiringRes.data) ? expiringRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const totalShares = rofrs.reduce((acc, r) => acc + Number(r.max_rofr_shares || 0), 0);
  const activeCount = rofrs.filter((r) => r.status === 'active').length;
  const exercisedCount = rofrs.filter((r) => r.status === 'exercised').length;
  const waivedCount = rofrs.filter((r) => r.status === 'waived').length;
  const expiredCount = rofrs.filter((r) => r.status === 'expired').length;

  const rofrCols: Column<any>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email || r.investor_id || '—' },
    { key: 'rofr_label', header: 'Label', render: (r: any) => r.rofr_label || '—' },
    { key: 'max_rofr_shares', header: 'Max Shares', render: (r: any) => Number(r.max_rofr_shares || 0).toLocaleString() },
    { key: 'status', header: 'Status', render: (r: any) => r.status || '—' },
    { key: 'expires_at', header: 'Expires', render: (r: any) => r.expires_at ? new Date(r.expires_at).toLocaleDateString() : '—' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '—' },
  ];

  const expiringCols: Column<any>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => r.investor_email || r.investor_id || '—' },
    { key: 'rofr_label', header: 'Label', render: (r: any) => r.rofr_label || '—' },
    { key: 'max_rofr_shares', header: 'Max Shares', render: (r: any) => Number(r.max_rofr_shares || 0).toLocaleString() },
    { key: 'expires_at', header: 'Expires', render: (r: any) => r.expires_at ? new Date(r.expires_at).toLocaleDateString() : '—' },
    { key: 'days_remaining', header: 'Days Left', render: (r: any) => String(r.days_remaining ?? '—') },
  ];

  const actionCols: Column<any>[] = [
    { key: 'rofr_id', header: 'ROFR', render: (r: any) => String(r.rofr_id || '').slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type || '—' },
    { key: 'shares_used', header: 'Shares Used', render: (r: any) => Number(r.shares_used || 0).toLocaleString() },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email || '—' },
    { key: 'taken_at', header: 'Taken At', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '—' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md || '—' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'rofr_id', header: 'ROFR', render: (r: any) => String(r.rofr_id || '').slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type || '—' },
    { key: 'shares_used', header: 'Shares Used', render: (r: any) => Number(r.shares_used || 0).toLocaleString() },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email || '—' },
    { key: 'taken_at', header: 'Taken At', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '—' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Investor Right-of-First-Refusal Tracker</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track investor ROFR rights, exercises, waivers, and expirations across rounds.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total ROFRs</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{rofrs.length}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Active</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{activeCount}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Exercised</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{exercisedCount}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Waived</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{waivedCount}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Expired</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{expiredCount}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total Shares Reserved</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{totalShares.toLocaleString()}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Expiring Soon (next 30 days)</h2>
        <DataTable rows={expiring} columns={expiringCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All ROFRs</h2>
        <DataTable rows={rofrs} columns={rofrCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Actions (last 14 days)</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Actions</h2>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
