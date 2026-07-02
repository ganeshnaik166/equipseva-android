import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type SessionRow = {
  id: string;
  coach_name: string;
  session_at: string;
  duration_minutes: number;
  topic: string;
  status: string;
  mood_rating: number | null;
  recording_url: string | null;
};

type ActionRow = {
  id: string;
  session_id: string;
  coach_name: string;
  action_text: string;
  due_date: string | null;
  status: string;
  completed_at: string | null;
  created_at: string;
};

type CoachSummaryRow = {
  coach_name: string;
  total_sessions: number;
  completed_sessions: number;
  upcoming_sessions: number;
  total_minutes: number;
  avg_mood: number | null;
  last_session_at: string | null;
};

type RecentRow = {
  id: string;
  coach_name: string;
  session_at: string;
  topic: string;
  duration_minutes: number;
  mood_rating: number | null;
  key_insight_md: string | null;
  action_committed_md: string | null;
};

function fmtDate(s: string | null) {
  if (!s) return '—';
  try {
    return new Date(s).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
  } catch {
    return s;
  }
}

function fmtDateOnly(s: string | null) {
  if (!s) return '—';
  try {
    return new Date(s).toLocaleDateString('en-IN', { dateStyle: 'medium' });
  } catch {
    return s;
  }
}

export default async function FounderCoachingSessionLogPage() {
  const sb = await getSupabaseServerClient();

  const [sessionsRes, actionsRes, coachRes, recentRes] = await Promise.all([
    sb.rpc('list_coaching_sessions_r1846', { p_limit: 50 }),
    sb.rpc('list_coaching_actions_r1846', { p_session_id: null, p_limit: 100 }),
    sb.rpc('coaching_coach_summary_r1846'),
    sb.rpc('coaching_recent_completed_r1846', { p_limit: 10 }),
  ]);

  const sessions: SessionRow[] = (sessionsRes.data as SessionRow[] | null) ?? [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[] | null) ?? [];
  const coaches: CoachSummaryRow[] = (coachRes.data as CoachSummaryRow[] | null) ?? [];
  const recent: RecentRow[] = (recentRes.data as RecentRow[] | null) ?? [];

  const sessionCols: Column<SessionRow>[] = [
    { key: 'session_at', header: 'Session At', render: (r: any) => <span>{fmtDate(r.session_at)}</span> },
    { key: 'coach_name', header: 'Coach', render: (r: any) => <span>{r.coach_name}</span> },
    { key: 'topic', header: 'Topic', render: (r: any) => <span>{r.topic}</span> },
    { key: 'duration_minutes', header: 'Duration (min)', render: (r: any) => <span>{r.duration_minutes}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span>{r.status}</span> },
    { key: 'mood_rating', header: 'Mood', render: (r: any) => <span>{r.mood_rating == null ? '—' : `${r.mood_rating}/10`}</span> },
    {
      key: 'recording_url',
      header: 'Recording',
      render: (r: any) =>
        r.recording_url ? (
          <a href={r.recording_url} target="_blank" rel="noreferrer" style={{ color: '#2563eb' }}>
            link
          </a>
        ) : (
          <span>—</span>
        ),
    },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'coach_name', header: 'Coach', render: (r: any) => <span>{r.coach_name}</span> },
    { key: 'action_text', header: 'Action', render: (r: any) => <span>{r.action_text}</span> },
    { key: 'due_date', header: 'Due', render: (r: any) => <span>{fmtDateOnly(r.due_date)}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span>{r.status}</span> },
    { key: 'completed_at', header: 'Completed', render: (r: any) => <span>{fmtDate(r.completed_at)}</span> },
    { key: 'created_at', header: 'Logged', render: (r: any) => <span>{fmtDate(r.created_at)}</span> },
  ];

  const coachCols: Column<CoachSummaryRow>[] = [
    { key: 'coach_name', header: 'Coach', render: (r: any) => <span>{r.coach_name}</span> },
    { key: 'total_sessions', header: 'Total', render: (r: any) => <span>{r.total_sessions}</span> },
    { key: 'completed_sessions', header: 'Completed', render: (r: any) => <span>{r.completed_sessions}</span> },
    { key: 'upcoming_sessions', header: 'Upcoming', render: (r: any) => <span>{r.upcoming_sessions}</span> },
    { key: 'total_minutes', header: 'Total Minutes', render: (r: any) => <span>{r.total_minutes}</span> },
    { key: 'avg_mood', header: 'Avg Mood', render: (r: any) => <span>{r.avg_mood == null ? '—' : Number(r.avg_mood).toFixed(2)}</span> },
    { key: 'last_session_at', header: 'Last Session', render: (r: any) => <span>{fmtDate(r.last_session_at)}</span> },
  ];

  const recentCols: Column<RecentRow>[] = [
    { key: 'session_at', header: 'When', render: (r: any) => <span>{fmtDate(r.session_at)}</span> },
    { key: 'coach_name', header: 'Coach', render: (r: any) => <span>{r.coach_name}</span> },
    { key: 'topic', header: 'Topic', render: (r: any) => <span>{r.topic}</span> },
    { key: 'duration_minutes', header: 'Min', render: (r: any) => <span>{r.duration_minutes}</span> },
    { key: 'mood_rating', header: 'Mood', render: (r: any) => <span>{r.mood_rating == null ? '—' : `${r.mood_rating}/10`}</span> },
    { key: 'key_insight_md', header: 'Key Insight', render: (r: any) => <span>{r.key_insight_md ?? '—'}</span> },
    { key: 'action_committed_md', header: 'Action Committed', render: (r: any) => <span>{r.action_committed_md ?? '—'}</span> },
  ];

  const totalSessions = sessions.length;
  const upcomingCount = sessions.filter((s) => s.status === 'upcoming').length;
  const completedCount = sessions.filter((s) => s.status === 'completed').length;
  const openActions = actions.filter((a) => a.status === 'open').length;

  return (
    <main style={{ padding: '24px', maxWidth: 1280, margin: '0 auto', fontFamily: 'system-ui, -apple-system, sans-serif' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, margin: 0 }}>Founder Coaching Session Log</h1>
        <p style={{ color: '#6b7280', marginTop: 8 }}>
          External executive-coach sessions & commitments. Track insights, action items, and mood across coaches.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 32 }}>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8, background: '#fff' }}>
          <div style={{ color: '#6b7280', fontSize: 12, textTransform: 'uppercase' }}>Total Sessions</div>
          <div style={{ fontSize: 28, fontWeight: 700 }}>{totalSessions}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8, background: '#fff' }}>
          <div style={{ color: '#6b7280', fontSize: 12, textTransform: 'uppercase' }}>Upcoming</div>
          <div style={{ fontSize: 28, fontWeight: 700, color: '#2563eb' }}>{upcomingCount}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8, background: '#fff' }}>
          <div style={{ color: '#6b7280', fontSize: 12, textTransform: 'uppercase' }}>Completed</div>
          <div style={{ fontSize: 28, fontWeight: 700, color: '#16a34a' }}>{completedCount}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8, background: '#fff' }}>
          <div style={{ color: '#6b7280', fontSize: 12, textTransform: 'uppercase' }}>Open Actions</div>
          <div style={{ fontSize: 28, fontWeight: 700, color: '#ea580c' }}>{openActions}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Coach Summary</h2>
        <DataTable
          rows={coaches}
          columns={coachCols}
          rowKey={(r: any, i: number) => String(r.coach_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Sessions (latest 50)</h2>
        <DataTable
          rows={sessions}
          columns={sessionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Action Log (open first, by due date)</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent Completed Sessions (with insights)</h2>
        <DataTable
          rows={recent}
          columns={recentCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <footer style={{ marginTop: 32, padding: 16, background: '#f9fafb', borderRadius: 8, color: '#6b7280', fontSize: 13 }}>
        Round r1846 · founder-only · mood scale 1–10 · actions auto-roll until marked done or dropped.
      </footer>
    </main>
  );
}
