import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type RecordRow = {
  id: string;
  hospital_id: string;
  hospital_name: string;
  lost_at: string;
  win_back_attempt_count: number;
  last_attempt_at: string | null;
  status: string;
  captured_at: string;
};

type ActiveRow = {
  id: string;
  hospital_id: string;
  hospital_name: string;
  lost_at: string;
  win_back_attempt_count: number;
  last_attempt_at: string | null;
  status: string;
};

type ActionRow = {
  id: string;
  record_id: string;
  action_type: string;
  taken_at: string;
  by_email: string | null;
  notes_md: string | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [recordsRes, activeRes, actionsRes] = await Promise.all([
    sb.rpc('r2179_list_records'),
    sb.rpc('r2179_active_attempts'),
    sb.rpc('r2179_recent_actions'),
  ]);

  const records: RecordRow[] = (recordsRes.data as RecordRow[]) ?? [];
  const active: ActiveRow[] = (activeRes.data as ActiveRow[]) ?? [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[]) ?? [];

  const recordCols: Column<RecordRow>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '-' },
    { key: 'lost_at', header: 'Lost At', render: (r: any) => r.lost_at ?? '-' },
    { key: 'win_back_attempt_count', header: 'Attempts', render: (r: any) => String(r.win_back_attempt_count ?? 0) },
    { key: 'last_attempt_at', header: 'Last Attempt', render: (r: any) => r.last_attempt_at ? new Date(r.last_attempt_at).toLocaleString() : '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '-' },
  ];

  const activeCols: Column<ActiveRow>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '-' },
    { key: 'lost_at', header: 'Lost At', render: (r: any) => r.lost_at ?? '-' },
    { key: 'win_back_attempt_count', header: 'Attempts', render: (r: any) => String(r.win_back_attempt_count ?? 0) },
    { key: 'last_attempt_at', header: 'Last Attempt', render: (r: any) => r.last_attempt_at ? new Date(r.last_attempt_at).toLocaleString() : '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'taken_at', header: 'Taken At', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '-' },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '-' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '-' },
    { key: 'record_id', header: 'Record', render: (r: any) => String(r.record_id ?? '').slice(0, 8) },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md ?? '-' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital Customer Win-Back Tracker</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track win-back attempts with lost hospital customers. Founder-only view.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Active Attempts</h2>
        <DataTable rows={active} columns={activeCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Records</h2>
        <DataTable rows={records} columns={recordCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Actions</h2>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
