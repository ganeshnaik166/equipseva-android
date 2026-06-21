import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

type EventRow = {
  id: string;
  engineer_user_id: string | null;
  engineer_email: string | null;
  event_date: string | null;
  event_type: string | null;
  start_time: string | null;
  end_time: string | null;
  event_title: string | null;
  status: string | null;
  repair_job_id: string | null;
  created_at: string | null;
};

type ConflictRow = {
  id: string;
  engineer_user_id: string | null;
  engineer_email: string | null;
  conflict_date: string | null;
  conflict_type: string | null;
  severity: string | null;
  resolution_action: string | null;
  resolved_at: string | null;
  created_at: string | null;
};

type DailySummaryRow = {
  engineer_user_id: string | null;
  engineer_email: string | null;
  total_events: number | null;
  jobs: number | null;
  shifts: number | null;
  leaves: number | null;
  trainings: number | null;
  meetings: number | null;
  conflicts: number | null;
};

type WeeklyLoadRow = {
  engineer_user_id: string | null;
  engineer_email: string | null;
  week_start: string | null;
  total_jobs: number | null;
  total_shifts: number | null;
  total_leaves: number | null;
  total_trainings: number | null;
  load_score: number | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [eventsRes, conflictsRes, dailyRes, weeklyRes] = await Promise.all([
    sb.rpc('list_events_r1784', {}),
    sb.rpc('list_conflicts_r1784', { p_only_unresolved: true }),
    sb.rpc('daily_summary_r1784', {}),
    sb.rpc('weekly_load_r1784', {}),
  ]);

  const events: EventRow[] = (eventsRes.data as EventRow[]) ?? [];
  const conflicts: ConflictRow[] = (conflictsRes.data as ConflictRow[]) ?? [];
  const daily: DailySummaryRow[] = (dailyRes.data as DailySummaryRow[]) ?? [];
  const weekly: WeeklyLoadRow[] = (weeklyRes.data as WeeklyLoadRow[]) ?? [];

  const totalEvents = events.length;
  const criticalConflicts = conflicts.filter((c) => c.severity === 'critical').length;
  const totalEngineersToday = daily.length;
  const heaviestLoad = weekly[0]?.load_score ?? 0;

  const eventCols: Column<EventRow>[] = [
    { key: 'event_date', header: 'Date', render: (r: any) => r.event_date ?? '-' },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '-' },
    { key: 'event_type', header: 'Type', render: (r: any) => r.event_type ?? '-' },
    { key: 'event_title', header: 'Title', render: (r: any) => r.event_title ?? '-' },
    {
      key: 'window',
      header: 'Window',
      render: (r: any) =>
        r.start_time && r.end_time ? `${r.start_time} - ${r.end_time}` : (r.start_time ?? '-'),
    },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
  ];

  const conflictCols: Column<ConflictRow>[] = [
    { key: 'conflict_date', header: 'Date', render: (r: any) => r.conflict_date ?? '-' },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '-' },
    { key: 'conflict_type', header: 'Conflict', render: (r: any) => r.conflict_type ?? '-' },
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity ?? '-' },
    {
      key: 'resolved',
      header: 'Resolved',
      render: (r: any) => (r.resolved_at ? 'yes' : 'no'),
    },
    {
      key: 'resolution_action',
      header: 'Action',
      render: (r: any) => r.resolution_action ?? '-',
    },
  ];

  const dailyCols: Column<DailySummaryRow>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '-' },
    { key: 'total_events', header: 'Total', render: (r: any) => r.total_events ?? 0 },
    { key: 'jobs', header: 'Jobs', render: (r: any) => r.jobs ?? 0 },
    { key: 'shifts', header: 'Shifts', render: (r: any) => r.shifts ?? 0 },
    { key: 'leaves', header: 'Leaves', render: (r: any) => r.leaves ?? 0 },
    { key: 'trainings', header: 'Trainings', render: (r: any) => r.trainings ?? 0 },
    { key: 'meetings', header: 'Meetings', render: (r: any) => r.meetings ?? 0 },
    { key: 'conflicts', header: 'Conflicts', render: (r: any) => r.conflicts ?? 0 },
  ];

  const weeklyCols: Column<WeeklyLoadRow>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '-' },
    { key: 'week_start', header: 'Week Start', render: (r: any) => r.week_start ?? '-' },
    { key: 'total_jobs', header: 'Jobs', render: (r: any) => r.total_jobs ?? 0 },
    { key: 'total_shifts', header: 'Shifts', render: (r: any) => r.total_shifts ?? 0 },
    { key: 'total_leaves', header: 'Leaves', render: (r: any) => r.total_leaves ?? 0 },
    { key: 'total_trainings', header: 'Trainings', render: (r: any) => r.total_trainings ?? 0 },
    { key: 'load_score', header: 'Load Score', render: (r: any) => r.load_score ?? 0 },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 4 }}>Engineer Calendar Master</h1>
        <p style={{ color: '#666', fontSize: 14 }}>
          Round 1784 · Combined view of jobs, shifts, leaves, training, meetings & conflicts
        </p>
      </header>

      <section
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
          gap: 12,
          marginBottom: 24,
        }}
      >
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Events in window</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{totalEvents}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Critical conflicts</div>
          <div style={{ fontSize: 24, fontWeight: 700, color: criticalConflicts > 0 ? '#dc2626' : '#111' }}>
            {criticalConflicts}
          </div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Engineers active today</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{totalEngineersToday}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Heaviest weekly load</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{heaviestLoad}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Calendar events</h2>
        <p style={{ fontSize: 12, color: '#666', marginBottom: 12 }}>
          Window: last 7 days → next 14 days. Up to 500 rows.
        </p>
        <DataTable
          rows={events}
          columns={eventCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Open conflicts</h2>
        <p style={{ fontSize: 12, color: '#666', marginBottom: 12 }}>
          Unresolved conflicts only. Run detect_conflicts_r1784 to refresh.
        </p>
        <DataTable
          rows={conflicts}
          columns={conflictCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Daily summary (today)</h2>
        <p style={{ fontSize: 12, color: '#666', marginBottom: 12 }}>
          Per-engineer event mix & conflict count for current date.
        </p>
        <DataTable
          rows={daily}
          columns={dailyCols}
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Weekly load</h2>
        <p style={{ fontSize: 12, color: '#666', marginBottom: 12 }}>
          Load score = jobs × 1.5 + shifts × 1.0 + trainings × 0.5. Sorted heaviest first.
        </p>
        <DataTable
          rows={weekly}
          columns={weeklyCols}
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </section>
    </div>
  );
}
