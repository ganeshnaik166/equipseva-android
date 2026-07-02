import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerMentorHoursPage() {
  const sb = await getSupabaseServerClient();

  const [mentorsRes, topMentorsRes, recentSessionsRes] = await Promise.all([
    sb.rpc('list_mentors_r1840'),
    sb.rpc('top_mentors_r1840'),
    sb.rpc('recent_sessions_r1840'),
  ]);

  const mentors: any[] = Array.isArray(mentorsRes.data) ? mentorsRes.data : [];
  const topMentors: any[] = Array.isArray(topMentorsRes.data) ? topMentorsRes.data : [];
  const recentSessions: any[] = Array.isArray(recentSessionsRes.data) ? recentSessionsRes.data : [];

  const activeCount = mentors.filter((m) => m.status === 'active').length;
  const pausedCount = mentors.filter((m) => m.status === 'paused').length;
  const endedCount = mentors.filter((m) => m.status === 'ended').length;
  const totalSessions = recentSessions.length;

  const mentorColumns: Column<any>[] = [
    { key: 'mentor_email', header: 'Mentor', render: (r: any) => <span className="text-sm">{r.mentor_email ?? '—'}</span> },
    { key: 'mentee_email', header: 'Mentee', render: (r: any) => <span className="text-sm">{r.mentee_email ?? '—'}</span> },
    { key: 'hours_per_month', header: 'Hrs/Mo', render: (r: any) => <span className="text-sm tabular-nums">{r.hours_per_month ?? 0}</span> },
    { key: 'started_on', header: 'Started', render: (r: any) => <span className="text-sm">{r.started_on ?? '—'}</span> },
    { key: 'status', header: 'Status', render: (r: any) => (
      <span className={`text-xs px-2 py-0.5 rounded-full ${r.status === 'active' ? 'bg-green-100 text-green-800' : r.status === 'paused' ? 'bg-yellow-100 text-yellow-800' : 'bg-gray-100 text-gray-800'}`}>{r.status ?? '—'}</span>
    ) },
    { key: 'sessions_count', header: 'Sessions', render: (r: any) => <span className="text-sm tabular-nums">{r.sessions_count ?? 0}</span> },
    { key: 'last_session_at', header: 'Last Session', render: (r: any) => <span className="text-xs text-gray-600">{r.last_session_at ? new Date(r.last_session_at).toLocaleDateString() : '—'}</span> },
    { key: 'founder_recognition', header: 'Recognition', render: (r: any) => <span className="text-xs text-gray-700">{r.founder_recognition ?? '—'}</span> },
  ];

  const topMentorColumns: Column<any>[] = [
    { key: 'mentor_email', header: 'Mentor', render: (r: any) => <span className="text-sm font-medium">{r.mentor_email ?? '—'}</span> },
    { key: 'active_mentees', header: 'Active Mentees', render: (r: any) => <span className="text-sm tabular-nums">{r.active_mentees ?? 0}</span> },
    { key: 'total_sessions', header: 'Sessions', render: (r: any) => <span className="text-sm tabular-nums">{r.total_sessions ?? 0}</span> },
    { key: 'total_minutes', header: 'Minutes', render: (r: any) => <span className="text-sm tabular-nums">{r.total_minutes ?? 0}</span> },
    { key: 'total_hours_per_month', header: 'Hrs/Mo', render: (r: any) => <span className="text-sm tabular-nums">{r.total_hours_per_month ?? 0}</span> },
  ];

  const recentSessionColumns: Column<any>[] = [
    { key: 'session_at', header: 'When', render: (r: any) => <span className="text-xs text-gray-600">{r.session_at ? new Date(r.session_at).toLocaleString() : '—'}</span> },
    { key: 'mentor_email', header: 'Mentor', render: (r: any) => <span className="text-sm">{r.mentor_email ?? '—'}</span> },
    { key: 'mentee_email', header: 'Mentee', render: (r: any) => <span className="text-sm">{r.mentee_email ?? '—'}</span> },
    { key: 'duration_minutes', header: 'Minutes', render: (r: any) => <span className="text-sm tabular-nums">{r.duration_minutes ?? 0}</span> },
    { key: 'topic', header: 'Topic', render: (r: any) => <span className="text-sm">{r.topic ?? '—'}</span> },
    { key: 'outcome', header: 'Outcome', render: (r: any) => <span className="text-xs text-gray-700">{r.outcome ?? '—'}</span> },
  ];

  return (
    <div className="p-6 max-w-7xl mx-auto space-y-8">
      <header className="space-y-2">
        <h1 className="text-2xl font-bold">Engineer Mentor Hours</h1>
        <p className="text-sm text-gray-600">
          Senior engineers mentoring juniors & founder recognition. Track pairings, sessions, and recognition.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="border rounded-lg p-4">
          <div className="text-xs text-gray-500 uppercase tracking-wide">Active</div>
          <div className="text-2xl font-semibold tabular-nums">{activeCount}</div>
        </div>
        <div className="border rounded-lg p-4">
          <div className="text-xs text-gray-500 uppercase tracking-wide">Paused</div>
          <div className="text-2xl font-semibold tabular-nums">{pausedCount}</div>
        </div>
        <div className="border rounded-lg p-4">
          <div className="text-xs text-gray-500 uppercase tracking-wide">Ended</div>
          <div className="text-2xl font-semibold tabular-nums">{endedCount}</div>
        </div>
        <div className="border rounded-lg p-4">
          <div className="text-xs text-gray-500 uppercase tracking-wide">Recent Sessions</div>
          <div className="text-2xl font-semibold tabular-nums">{totalSessions}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Top Mentors</h2>
        <p className="text-sm text-gray-600">Ranked by session count & active mentees.</p>
        <DataTable rows={topMentors} columns={topMentorColumns} rowKey={(r: any, i: number) => String(r.mentor_user_id ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">All Mentorships</h2>
        <p className="text-sm text-gray-600">Every active, paused & ended pairing.</p>
        <DataTable rows={mentors} columns={mentorColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Recent Sessions</h2>
        <p className="text-sm text-gray-600">Last 100 logged mentor &lt;&gt; mentee sessions.</p>
        <DataTable rows={recentSessions} columns={recentSessionColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
