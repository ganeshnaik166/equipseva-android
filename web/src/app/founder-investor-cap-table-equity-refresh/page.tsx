import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Refresh = {
  id: string;
  recipient_label: string;
  refresh_event_label: string;
  refresh_shares: number;
  refresh_date: string | null;
  vesting_start_date: string | null;
  status: string;
  captured_at: string;
};

type ActionRow = {
  id: string;
  refresh_id: string;
  action_type: string;
  taken_at: string;
  by_email: string | null;
  shares_change: number;
};

type RecentRefresh = {
  id: string;
  recipient_label: string;
  refresh_event_label: string;
  refresh_shares: number;
  status: string;
  captured_at: string;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [refreshesRes, recentRefreshRes, recentActionsRes] = await Promise.all([
    sb.rpc('list_refreshes_r2181'),
    sb.rpc('recent_refreshes_r2181', { p_limit: 20 }),
    sb.rpc('recent_actions_r2181', { p_limit: 20 }),
  ]);

  const refreshes: Refresh[] = (refreshesRes.data as Refresh[]) ?? [];
  const recentRefreshes: RecentRefresh[] = (recentRefreshRes.data as RecentRefresh[]) ?? [];
  const recentActions: ActionRow[] = (recentActionsRes.data as ActionRow[]) ?? [];

  const refreshCols: Column<Refresh>[] = [
    { key: 'recipient_label', header: 'Recipient', render: (r: any) => r.recipient_label },
    { key: 'refresh_event_label', header: 'Event', render: (r: any) => r.refresh_event_label },
    { key: 'refresh_shares', header: 'Shares', render: (r: any) => String(r.refresh_shares ?? 0) },
    { key: 'refresh_date', header: 'Refresh Date', render: (r: any) => r.refresh_date ?? '-' },
    { key: 'vesting_start_date', header: 'Vesting Start', render: (r: any) => r.vesting_start_date ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'captured_at', header: 'Captured', render: (r: any) => new Date(r.captured_at).toLocaleString() },
  ];

  const recentRefreshCols: Column<RecentRefresh>[] = [
    { key: 'recipient_label', header: 'Recipient', render: (r: any) => r.recipient_label },
    { key: 'refresh_event_label', header: 'Event', render: (r: any) => r.refresh_event_label },
    { key: 'refresh_shares', header: 'Shares', render: (r: any) => String(r.refresh_shares ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'captured_at', header: 'Captured', render: (r: any) => new Date(r.captured_at).toLocaleString() },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'refresh_id', header: 'Refresh', render: (r: any) => String(r.refresh_id).slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type },
    { key: 'shares_change', header: 'Shares Change', render: (r: any) => String(r.shares_change ?? 0) },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '-' },
    { key: 'taken_at', header: 'Taken At', render: (r: any) => new Date(r.taken_at).toLocaleString() },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Investor Cap Table Equity Refresh</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track equity refresh grants for recipients, vesting schedules and lifecycle actions.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Refresh Grants</h2>
        <DataTable
          rows={refreshes}
          columns={refreshCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Refreshes</h2>
        <DataTable
          rows={recentRefreshes}
          columns={recentRefreshCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Actions</h2>
        <DataTable
          rows={recentActions}
          columns={actionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
