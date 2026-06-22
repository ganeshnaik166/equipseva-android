import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const { data: schedules } = await sb.rpc('list_vesting_schedules_r2153');
  const { data: fullyVested } = await sb.rpc('list_fully_vested_r2153');
  const { data: recentActions } = await sb.rpc('list_recent_vesting_actions_r2153');

  const scheduleRows: any[] = Array.isArray(schedules) ? schedules : [];
  const fullyVestedRows: any[] = Array.isArray(fullyVested) ? fullyVested : [];
  const recentActionRows: any[] = Array.isArray(recentActions) ? recentActions : [];

  const scheduleCols: Column<any>[] = [
    { key: 'recipient_label', header: 'Recipient', render: (r: any) => String(r.recipient_label ?? '') },
    { key: 'total_shares', header: 'Total Shares', render: (r: any) => String(r.total_shares ?? 0) },
    { key: 'vested_shares', header: 'Vested Shares', render: (r: any) => String(r.vested_shares ?? 0) },
    { key: 'vesting_start_date', header: 'Start', render: (r: any) => String(r.vesting_start_date ?? '') },
    { key: 'vesting_end_date', header: 'End', render: (r: any) => String(r.vesting_end_date ?? '') },
    { key: 'cliff_months', header: 'Cliff (mo)', render: (r: any) => String(r.cliff_months ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const fullyVestedCols: Column<any>[] = [
    { key: 'recipient_label', header: 'Recipient', render: (r: any) => String(r.recipient_label ?? '') },
    { key: 'total_shares', header: 'Total Shares', render: (r: any) => String(r.total_shares ?? 0) },
    { key: 'vested_shares', header: 'Vested', render: (r: any) => String(r.vested_shares ?? 0) },
    { key: 'vesting_end_date', header: 'Vested On', render: (r: any) => String(r.vesting_end_date ?? '') },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'shares_vested', header: 'Shares', render: (r: any) => String(r.shares_vested ?? 0) },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'When', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
  ];

  return (
    <main style={{ padding: 24 }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Investor Cap Table Vesting Schedule</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Vesting schedules per investor and employee. Cliff, total grant, vested-to-date, plus accelerated and terminated events.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Schedules</h2>
        <DataTable
          rows={scheduleRows}
          columns={scheduleCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Fully Vested</h2>
        <DataTable
          rows={fullyVestedRows}
          columns={fullyVestedCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Actions</h2>
        <DataTable
          rows={recentActionRows}
          columns={actionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
