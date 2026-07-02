import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type SyncRow = {
  id: string;
  sync_title: string;
  sync_date: string;
  week_iso: string;
  teams_count: number;
  invited_count: number;
  attended_count: number;
  attendance_pct: number;
  duration_minutes: number;
  status: string;
  decision_count: number;
  open_action_count: number;
};

type ActionRow = {
  id: string;
  sync_id: string;
  sync_title: string;
  sync_date: string;
  decision_text: string;
  decision_type: string;
  owner_id: string | null;
  owner_email: string | null;
  due_date: string | null;
  days_overdue: number;
  status: string;
};

type RoiRow = {
  week_iso: string;
  syncs_held: number;
  syncs_cancelled: number;
  total_invited: number;
  total_attended: number;
  attendance_pct: number;
  total_decisions: number;
  total_actions: number;
  closed_actions: number;
  open_actions: number;
  decisions_per_sync: number;
  attendance_x_decisions: number;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [syncsRes, actionsRes, roiRes] = await Promise.all([
    sb.rpc('list_syncs_r2365'),
    sb.rpc('open_sync_actions_r2365'),
    sb.rpc('weekly_sync_roi_r2365'),
  ]);

  const syncs: SyncRow[] = (syncsRes.data as SyncRow[] | null) ?? [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[] | null) ?? [];
  const roi: RoiRow[] = (roiRes.data as RoiRow[] | null) ?? [];

  const syncCols: Column<SyncRow>[] = [
    { key: 'sync_date', header: 'Date', render: (r: any) => r.sync_date },
    { key: 'week_iso', header: 'Week', render: (r: any) => r.week_iso },
    { key: 'sync_title', header: 'Title', render: (r: any) => r.sync_title },
    { key: 'teams_count', header: 'Teams', render: (r: any) => r.teams_count },
    { key: 'invited_count', header: 'Invited', render: (r: any) => r.invited_count },
    { key: 'attended_count', header: 'Attended', render: (r: any) => r.attended_count },
    { key: 'attendance_pct', header: 'Attendance %', render: (r: any) => `${r.attendance_pct}%` },
    { key: 'duration_minutes', header: 'Mins', render: (r: any) => r.duration_minutes },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'decision_count', header: 'Decisions', render: (r: any) => r.decision_count },
    { key: 'open_action_count', header: 'Open actions', render: (r: any) => r.open_action_count },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'sync_date', header: 'Sync date', render: (r: any) => r.sync_date },
    { key: 'sync_title', header: 'Sync', render: (r: any) => r.sync_title },
    { key: 'decision_type', header: 'Type', render: (r: any) => r.decision_type },
    { key: 'decision_text', header: 'Item', render: (r: any) => r.decision_text },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'due_date', header: 'Due', render: (r: any) => r.due_date ?? '—' },
    { key: 'days_overdue', header: 'Days overdue', render: (r: any) => r.days_overdue },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const roiCols: Column<RoiRow>[] = [
    { key: 'week_iso', header: 'Week', render: (r: any) => r.week_iso },
    { key: 'syncs_held', header: 'Held', render: (r: any) => r.syncs_held },
    { key: 'syncs_cancelled', header: 'Cancelled', render: (r: any) => r.syncs_cancelled },
    { key: 'total_invited', header: 'Invited', render: (r: any) => r.total_invited },
    { key: 'total_attended', header: 'Attended', render: (r: any) => r.total_attended },
    { key: 'attendance_pct', header: 'Attendance %', render: (r: any) => `${r.attendance_pct}%` },
    { key: 'total_decisions', header: 'Decisions', render: (r: any) => r.total_decisions },
    { key: 'total_actions', header: 'Actions', render: (r: any) => r.total_actions },
    { key: 'closed_actions', header: 'Closed', render: (r: any) => r.closed_actions },
    { key: 'open_actions', header: 'Open', render: (r: any) => r.open_actions },
    { key: 'decisions_per_sync', header: 'Items/sync', render: (r: any) => r.decisions_per_sync },
    { key: 'attendance_x_decisions', header: 'ROI score', render: (r: any) => r.attendance_x_decisions },
  ];

  const totalSyncs = syncs.length;
  const heldSyncs = syncs.filter((s) => s.status === 'held').length;
  const totalDecisions = syncs.reduce((acc, s) => acc + (s.decision_count || 0), 0);
  const totalOpenActions = syncs.reduce((acc, s) => acc + (s.open_action_count || 0), 0);
  const overdueActions = actions.filter((a) => a.days_overdue > 0).length;
  const avgAttendance = syncs.length === 0
    ? 0
    : Math.round((syncs.reduce((acc, s) => acc + Number(s.attendance_pct || 0), 0) / syncs.length) * 10) / 10;

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Weekly cross-functional sync ROI
      </h1>
      <p style={{ color: '#555', marginBottom: 16 }}>
        Measure whether cross-team syncs produce decisions &amp; outputs. Attendance &times; decisions =&gt; ROI score.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        <div style={{ border: '1px solid #ddd', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total syncs</div>
          <div style={{ fontSize: 22, fontWeight: 600 }}>{totalSyncs}</div>
        </div>
        <div style={{ border: '1px solid #ddd', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Held</div>
          <div style={{ fontSize: 22, fontWeight: 600 }}>{heldSyncs}</div>
        </div>
        <div style={{ border: '1px solid #ddd', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Avg attendance</div>
          <div style={{ fontSize: 22, fontWeight: 600 }}>{avgAttendance}%</div>
        </div>
        <div style={{ border: '1px solid #ddd', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Decisions logged</div>
          <div style={{ fontSize: 22, fontWeight: 600 }}>{totalDecisions}</div>
        </div>
        <div style={{ border: '1px solid #ddd', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Open actions</div>
          <div style={{ fontSize: 22, fontWeight: 600 }}>{totalOpenActions}</div>
        </div>
        <div style={{ border: '1px solid #ddd', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Overdue actions</div>
          <div style={{ fontSize: 22, fontWeight: 600, color: overdueActions > 0 ? '#b00' : undefined }}>{overdueActions}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Weekly ROI rollup</h2>
        <DataTable
          rows={roi}
          columns={roiCols}
          emptyMessage="No weeks yet"
          rowKey={(r: any) => r.week_iso}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All syncs</h2>
        <DataTable
          rows={syncs}
          columns={syncCols}
          emptyMessage="No syncs scheduled"
          rowKey={(r: any) => r.id}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Open actions & decisions</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          emptyMessage="No open actions"
          rowKey={(r: any) => r.id}
        />
      </section>
    </main>
  );
}
