import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [coveragesRes, expiringRes, recentActionsRes] = await Promise.all([
    sb.rpc('list_coverages_r1960'),
    sb.rpc('expiring_coverage_r1960', { p_days: 30 }),
    sb.rpc('recent_actions_r1960', { p_limit: 50 }),
  ]);

  const coverages = (coveragesRes.data ?? []) as any[];
  const expiring = (expiringRes.data ?? []) as any[];
  const recentActions = (recentActionsRes.data ?? []) as any[];

  const coverageCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'coverage_type', header: 'Type', render: (r: any) => String(r.coverage_type ?? '') },
    { key: 'premium_rupees', header: 'Premium', render: (r: any) => `₹${Number(r.premium_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'coverage_start_date', header: 'Start', render: (r: any) => String(r.coverage_start_date ?? '') },
    { key: 'coverage_end_date', header: 'End', render: (r: any) => String(r.coverage_end_date ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'last_premium_paid_at', header: 'Last Paid', render: (r: any) => r.last_premium_paid_at ? new Date(r.last_premium_paid_at).toLocaleDateString() : '-' },
  ];

  const expiringCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'coverage_type', header: 'Type', render: (r: any) => String(r.coverage_type ?? '') },
    { key: 'coverage_end_date', header: 'Expires', render: (r: any) => String(r.coverage_end_date ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'premium_rupees', header: 'Premium', render: (r: any) => `₹${Number(r.premium_rupees ?? 0).toLocaleString('en-IN')}` },
  ];

  const actionCols: Column<any>[] = [
    { key: 'taken_at', header: 'Taken At', render: (r: any) => new Date(r.taken_at).toLocaleString() },
    { key: 'coverage_id', header: 'Coverage', render: (r: any) => String(r.coverage_id ?? '').slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '-') },
    { key: 'amount_rupees', header: 'Amount', render: (r: any) => r.amount_rupees != null ? `₹${Number(r.amount_rupees).toLocaleString('en-IN')}` : '-' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 80) },
  ];

  const activeCount = coverages.filter((c) => c.status === 'active').length;
  const lapsedCount = coverages.filter((c) => c.status === 'lapsed').length;
  const totalPremium = coverages.reduce((sum, c) => sum + Number(c.premium_rupees ?? 0), 0);

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Engineer Insurance & Welfare Tracker</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>Round 1960 — track engineer insurance & welfare coverage.</p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Summary</h2>
        <div style={{ display: 'flex', gap: 16, flexWrap: 'wrap' }}>
          <div style={{ padding: 16, background: '#f5f5f5', borderRadius: 8, minWidth: 160 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Total Coverages</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{coverages.length}</div>
          </div>
          <div style={{ padding: 16, background: '#e8f5e9', borderRadius: 8, minWidth: 160 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Active</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{activeCount}</div>
          </div>
          <div style={{ padding: 16, background: '#ffebee', borderRadius: 8, minWidth: 160 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Lapsed</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{lapsedCount}</div>
          </div>
          <div style={{ padding: 16, background: '#fff8e1', borderRadius: 8, minWidth: 160 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Total Premium</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{`₹${totalPremium.toLocaleString('en-IN')}`}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Coverages</h2>
        <DataTable rows={coverages} columns={coverageCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Expiring within 30 days</h2>
        <DataTable rows={expiring} columns={expiringCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Actions</h2>
        <DataTable rows={recentActions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
