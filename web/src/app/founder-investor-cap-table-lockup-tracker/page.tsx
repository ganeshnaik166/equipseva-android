import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type LockupRow = {
  id: string;
  investor_id: string;
  lockup_label: string;
  locked_shares_count: number;
  lockup_starts_at: string | null;
  lockup_ends_at: string | null;
  status: string;
  captured_at: string;
};

type ExpiringRow = {
  id: string;
  investor_id: string;
  lockup_label: string;
  locked_shares_count: number;
  lockup_ends_at: string | null;
  status: string;
  days_remaining: number | null;
};

type ActionRow = {
  id: string;
  lockup_id: string;
  action_type: string;
  taken_at: string;
  by_email: string | null;
  shares_released: number;
  notes_md: string | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [lockupsRes, expiringRes, actionsRes] = await Promise.all([
    sb.rpc('list_lockups_r2101'),
    sb.rpc('expiring_soon_r2101'),
    sb.rpc('recent_actions_r2101'),
  ]);

  const lockups: LockupRow[] = (lockupsRes.data as LockupRow[]) ?? [];
  const expiring: ExpiringRow[] = (expiringRes.data as ExpiringRow[]) ?? [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[]) ?? [];

  const lockupCols: Column<LockupRow>[] = [
    { key: 'lockup_label', header: 'Label', render: (r: any) => String(r.lockup_label ?? '') },
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id ?? '').slice(0, 8) },
    { key: 'locked_shares_count', header: 'Shares Locked', render: (r: any) => Number(r.locked_shares_count ?? 0).toLocaleString('en-IN') },
    { key: 'lockup_starts_at', header: 'Starts', render: (r: any) => r.lockup_starts_at ? String(r.lockup_starts_at) : 'n/a' },
    { key: 'lockup_ends_at', header: 'Ends', render: (r: any) => r.lockup_ends_at ? String(r.lockup_ends_at) : 'n/a' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => new Date(r.captured_at).toLocaleString('en-IN') },
  ];

  const expiringCols: Column<ExpiringRow>[] = [
    { key: 'lockup_label', header: 'Label', render: (r: any) => String(r.lockup_label ?? '') },
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id ?? '').slice(0, 8) },
    { key: 'locked_shares_count', header: 'Shares', render: (r: any) => Number(r.locked_shares_count ?? 0).toLocaleString('en-IN') },
    { key: 'lockup_ends_at', header: 'Ends', render: (r: any) => r.lockup_ends_at ? String(r.lockup_ends_at) : 'n/a' },
    { key: 'days_remaining', header: 'Days Left', render: (r: any) => r.days_remaining == null ? 'n/a' : String(r.days_remaining) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'taken_at', header: 'Taken', render: (r: any) => new Date(r.taken_at).toLocaleString('en-IN') },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'lockup_id', header: 'Lockup', render: (r: any) => String(r.lockup_id ?? '').slice(0, 8) },
    { key: 'shares_released', header: 'Shares Released', render: (r: any) => Number(r.shares_released ?? 0).toLocaleString('en-IN') },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ? String(r.by_email) : 'system' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md ? String(r.notes_md).slice(0, 80) : '' },
  ];

  const totalShares = lockups.reduce((sum, l) => sum + Number(l.locked_shares_count ?? 0), 0);
  const activeCount = lockups.filter((l) => l.status === 'active').length;

  return (
    <main style={{ padding: '2rem', maxWidth: '1280px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', fontWeight: 700, marginBottom: '0.5rem' }}>
        Investor Cap Table Lockup Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '1.5rem' }}>
        Track investor share lockup windows, action history, and lockups expiring within ninety days.
      </p>

      <section style={{ display: 'flex', gap: '1rem', marginBottom: '2rem', flexWrap: 'wrap' }}>
        <div style={{ padding: '1rem', border: '1px solid #ddd', borderRadius: '8px', minWidth: '180px' }}>
          <div style={{ fontSize: '0.85rem', color: '#666' }}>Total lockups</div>
          <div style={{ fontSize: '1.5rem', fontWeight: 600 }}>{lockups.length}</div>
        </div>
        <div style={{ padding: '1rem', border: '1px solid #ddd', borderRadius: '8px', minWidth: '180px' }}>
          <div style={{ fontSize: '0.85rem', color: '#666' }}>Active lockups</div>
          <div style={{ fontSize: '1.5rem', fontWeight: 600 }}>{activeCount}</div>
        </div>
        <div style={{ padding: '1rem', border: '1px solid #ddd', borderRadius: '8px', minWidth: '180px' }}>
          <div style={{ fontSize: '0.85rem', color: '#666' }}>Total locked shares</div>
          <div style={{ fontSize: '1.5rem', fontWeight: 600 }}>{totalShares.toLocaleString('en-IN')}</div>
        </div>
        <div style={{ padding: '1rem', border: '1px solid #ddd', borderRadius: '8px', minWidth: '180px' }}>
          <div style={{ fontSize: '0.85rem', color: '#666' }}>Expiring in 90 days</div>
          <div style={{ fontSize: '1.5rem', fontWeight: 600 }}>{expiring.length}</div>
        </div>
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>All lockups</h2>
        <DataTable
          rows={lockups}
          columns={lockupCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Expiring soon</h2>
        <p style={{ color: '#666', fontSize: '0.9rem', marginBottom: '0.5rem' }}>
          Active lockups with end date within the next ninety days.
        </p>
        <DataTable
          rows={expiring}
          columns={expiringCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Recent actions</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
