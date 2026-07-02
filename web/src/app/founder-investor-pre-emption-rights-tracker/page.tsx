import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [rightsRes, expiringRes, recentRes] = await Promise.all([
    sb.rpc('list_pre_emption_rights_r1997'),
    sb.rpc('list_pre_emption_expiring_soon_r1997'),
    sb.rpc('list_pre_emption_recent_actions_r1997'),
  ]);

  const rights = (rightsRes.data ?? []) as any[];
  const expiring = (expiringRes.data ?? []) as any[];
  const recent = (recentRes.data ?? []) as any[];

  const rightsCols: Column<any>[] = [
    { key: 'round_label', header: 'Round', render: (r: any) => String(r.round_label ?? '') },
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id ?? '').slice(0, 8) },
    { key: 'pre_emption_pct_entitled', header: 'Pct entitled', render: (r: any) => `${Number(r.pre_emption_pct_entitled ?? 0).toFixed(2)}%` },
    { key: 'pre_emption_shares_entitled', header: 'Shares entitled', render: (r: any) => Number(r.pre_emption_shares_entitled ?? 0).toLocaleString() },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'expires_at', header: 'Expires', render: (r: any) => r.expires_at ? new Date(r.expires_at).toLocaleDateString() : 'n/a' },
    { key: 'decided_at', header: 'Decided', render: (r: any) => r.decided_at ? new Date(r.decided_at).toLocaleDateString() : 'pending' },
  ];

  const expiringCols: Column<any>[] = [
    { key: 'round_label', header: 'Round', render: (r: any) => String(r.round_label ?? '') },
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id ?? '').slice(0, 8) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'expires_at', header: 'Expires at', render: (r: any) => r.expires_at ? new Date(r.expires_at).toLocaleString() : '' },
    { key: 'days_left', header: 'Days left', render: (r: any) => String(r.days_left ?? 0) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'taken_at', header: 'When', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'right_id', header: 'Right', render: (r: any) => String(r.right_id ?? '').slice(0, 8) },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'shares_taken', header: 'Shares taken', render: (r: any) => r.shares_taken != null ? Number(r.shares_taken).toLocaleString() : 'n/a' },
  ];

  const activeCount = rights.filter((r) => r.status === 'active').length;
  const exercisedCount = rights.filter((r) => r.status === 'exercised').length;
  const waivedCount = rights.filter((r) => r.status === 'waived').length;

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Investor pre-emption rights tracker</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track pre-emption rights across financing rounds. Active rights count {activeCount}, exercised count {exercisedCount},
        waived count {waivedCount}.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All rights</h2>
        <DataTable rows={rights} columns={rightsCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Expiring within 30 days</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 14 }}>
          Active rights with expiry window of 30 days or fewer. Notify investors and capture decisions.
        </p>
        <DataTable rows={expiring} columns={expiringCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent actions</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 14 }}>
          Latest exercise, waive, expire, notify, and extension events.
        </p>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
