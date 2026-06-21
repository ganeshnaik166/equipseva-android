import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type SnapshotRow = {
  id: string;
  taken_at: string;
  session_topic: string;
  image_url: string | null;
  status: string;
  follow_up_required: boolean;
  action_count: number;
  open_action_count: number;
};

type ActionRow = {
  id: string;
  snapshot_id: string;
  session_topic: string;
  action_text: string;
  owner_email: string | null;
  due_date: string | null;
  status: string;
  created_at: string;
};

type TopicRow = {
  session_topic: string;
  snapshot_count: number;
  last_taken_at: string;
  open_actions: number;
};

type ActionableRow = {
  id: string;
  taken_at: string;
  session_topic: string;
  status: string;
  open_actions: number;
  overdue_actions: number;
};

function fmtDate(s: string | null) {
  if (!s) return '—';
  try { return new Date(s).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' }); } catch { return s; }
}

function fmtDay(s: string | null) {
  if (!s) return '—';
  try { return new Date(s).toLocaleDateString('en-IN', { dateStyle: 'medium' }); } catch { return s; }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [snapsRes, actionsRes, topicsRes, actionableRes] = await Promise.all([
    sb.rpc('list_snapshots_r1782'),
    sb.rpc('list_actions_r1782', { p_snapshot_id: null }),
    sb.rpc('recent_topics_r1782'),
    sb.rpc('actionable_snapshots_r1782'),
  ]);

  const snaps: SnapshotRow[] = (snapsRes.data as SnapshotRow[]) ?? [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[]) ?? [];
  const topics: TopicRow[] = (topicsRes.data as TopicRow[]) ?? [];
  const actionable: ActionableRow[] = (actionableRes.data as ActionableRow[]) ?? [];

  const totalSnaps = snaps.length;
  const totalOpenActions = actions.filter(a => a.status === 'open').length;
  const overdueOpen = actions.filter(a => a.status === 'open' && a.due_date && new Date(a.due_date) < new Date()).length;
  const needsFollowUp = snaps.filter(s => s.follow_up_required && s.status !== 'archived').length;

  const snapCols: Column<SnapshotRow>[] = [
    { key: 'taken_at', header: 'Taken', render: (r: any) => fmtDate(r.taken_at) },
    { key: 'session_topic', header: 'Topic', render: (r: any) => r.session_topic },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'follow_up_required', header: 'Follow up', render: (r: any) => (r.follow_up_required ? 'yes' : 'no') },
    { key: 'action_count', header: 'Actions', render: (r: any) => String(r.action_count ?? 0) },
    { key: 'open_action_count', header: 'Open', render: (r: any) => String(r.open_action_count ?? 0) },
    { key: 'image_url', header: 'Image', render: (r: any) => (r.image_url ? 'attached' : '—') },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'session_topic', header: 'Topic', render: (r: any) => r.session_topic },
    { key: 'action_text', header: 'Action', render: (r: any) => r.action_text },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'due_date', header: 'Due', render: (r: any) => fmtDay(r.due_date) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'created_at', header: 'Logged', render: (r: any) => fmtDate(r.created_at) },
  ];

  const topicCols: Column<TopicRow>[] = [
    { key: 'session_topic', header: 'Topic', render: (r: any) => r.session_topic },
    { key: 'snapshot_count', header: 'Sessions', render: (r: any) => String(r.snapshot_count ?? 0) },
    { key: 'last_taken_at', header: 'Last seen', render: (r: any) => fmtDate(r.last_taken_at) },
    { key: 'open_actions', header: 'Open actions', render: (r: any) => String(r.open_actions ?? 0) },
  ];

  const actionableCols: Column<ActionableRow>[] = [
    { key: 'taken_at', header: 'Taken', render: (r: any) => fmtDate(r.taken_at) },
    { key: 'session_topic', header: 'Topic', render: (r: any) => r.session_topic },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'open_actions', header: 'Open', render: (r: any) => String(r.open_actions ?? 0) },
    { key: 'overdue_actions', header: 'Overdue', render: (r: any) => String(r.overdue_actions ?? 0) },
  ];

  return (
    <main style={{ padding: '1.5rem', maxWidth: 1240, margin: '0 auto' }}>
      <header style={{ marginBottom: '1.25rem' }}>
        <h1 style={{ fontSize: '1.5rem', fontWeight: 700, marginBottom: '.25rem' }}>Founder Whiteboard Snapshots</h1>
        <p style={{ color: '#555', fontSize: '.9rem' }}>
          Photos & transcripts of physical whiteboard sessions. Track action items captured during deep-work.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '.75rem', marginBottom: '1.5rem' }}>
        <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: '.85rem' }}>
          <div style={{ fontSize: '.75rem', color: '#6b7280' }}>Snapshots</div>
          <div style={{ fontSize: '1.4rem', fontWeight: 700 }}>{totalSnaps}</div>
        </div>
        <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: '.85rem' }}>
          <div style={{ fontSize: '.75rem', color: '#6b7280' }}>Open actions</div>
          <div style={{ fontSize: '1.4rem', fontWeight: 700 }}>{totalOpenActions}</div>
        </div>
        <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: '.85rem' }}>
          <div style={{ fontSize: '.75rem', color: '#6b7280' }}>Overdue</div>
          <div style={{ fontSize: '1.4rem', fontWeight: 700, color: overdueOpen > 0 ? '#b91c1c' : undefined }}>{overdueOpen}</div>
        </div>
        <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: '.85rem' }}>
          <div style={{ fontSize: '.75rem', color: '#6b7280' }}>Needs follow-up</div>
          <div style={{ fontSize: '1.4rem', fontWeight: 700 }}>{needsFollowUp}</div>
        </div>
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.1rem', fontWeight: 600, marginBottom: '.5rem' }}>Actionable snapshots</h2>
        <p style={{ color: '#6b7280', fontSize: '.85rem', marginBottom: '.5rem' }}>
          Snapshots flagged follow-up where status &lt;&gt; archived.
        </p>
        <DataTable<ActionableRow>
          rows={actionable}
          columns={actionableCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.1rem', fontWeight: 600, marginBottom: '.5rem' }}>Recent topics (60d)</h2>
        <DataTable<TopicRow>
          rows={topics}
          columns={topicCols}
          rowKey={(r: any, i: number) => String(r.session_topic ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.1rem', fontWeight: 600, marginBottom: '.5rem' }}>All snapshots</h2>
        <DataTable<SnapshotRow>
          rows={snaps}
          columns={snapCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.1rem', fontWeight: 600, marginBottom: '.5rem' }}>Action items</h2>
        <DataTable<ActionRow>
          rows={actions}
          columns={actionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
