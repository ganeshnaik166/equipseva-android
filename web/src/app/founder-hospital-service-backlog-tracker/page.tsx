import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Backlog = {
  id: string;
  hospital_id: string;
  total_open_jobs: number;
  overdue_jobs: number;
  days_oldest_open: number;
  status: string;
  captured_at: string;
};

type Action = {
  id: string;
  backlog_id: string;
  action_type: string;
  taken_at: string;
  by_email: string | null;
  notes_md: string | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [allRes, critRes, recentRes] = await Promise.all([
    sb.rpc('list_backlogs_r2043'),
    sb.rpc('critical_backlogs_r2043'),
    sb.rpc('recent_actions_r2043'),
  ]);

  const all: Backlog[] = (allRes.data as Backlog[]) ?? [];
  const crit: Backlog[] = (critRes.data as Backlog[]) ?? [];
  const recent: Action[] = (recentRes.data as Action[]) ?? [];

  const backlogCols: Column<Backlog>[] = [
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id).slice(0, 8) },
    { key: 'total_open_jobs', header: 'Open Jobs', render: (r: any) => String(r.total_open_jobs) },
    { key: 'overdue_jobs', header: 'Overdue', render: (r: any) => String(r.overdue_jobs) },
    { key: 'days_oldest_open', header: 'Days Oldest', render: (r: any) => String(r.days_oldest_open) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status) },
    { key: 'captured_at', header: 'Captured', render: (r: any) => new Date(r.captured_at).toLocaleString() },
  ];

  const actionCols: Column<Action>[] = [
    { key: 'backlog_id', header: 'Backlog', render: (r: any) => String(r.backlog_id).slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type) },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '' },
    { key: 'taken_at', header: 'Taken', render: (r: any) => new Date(r.taken_at).toLocaleString() },
    { key: 'notes_md', header: 'Notes', render: (r: any) => (r.notes_md ?? '').slice(0, 80) },
  ];

  return (
    <div style={{ padding: 24 }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital Service Backlog Tracker</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Round r2043. Track open job backlog per hospital. Status escalates normal then elevated then severe then critical.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Critical and Severe Backlogs</h2>
        <DataTable rows={crit} columns={backlogCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Backlog Snapshots</h2>
        <DataTable rows={all} columns={backlogCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Actions</h2>
        <DataTable rows={recent} columns={actionCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
