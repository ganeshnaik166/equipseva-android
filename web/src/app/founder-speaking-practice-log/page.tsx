import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderSpeakingPracticeLogPage() {
  const sb = await getSupabaseServerClient();

  const [practicesRes, upcomingRes, deliveriesRes, feedbackRes] = await Promise.all([
    sb.rpc('list_practices_r1838'),
    sb.rpc('top_upcoming_r1838'),
    sb.rpc('recent_deliveries_r1838'),
    sb.rpc('list_feedback_r1838', { p_session_id: null }),
  ]);

  const practices: any[] = (practicesRes.data as any[]) || [];
  const upcoming: any[] = (upcomingRes.data as any[]) || [];
  const deliveries: any[] = (deliveriesRes.data as any[]) || [];
  const feedback: any[] = (feedbackRes.data as any[]) || [];

  const totalSessions = practices.length;
  const scheduledCount = practices.filter((p) => p.status === 'scheduled').length;
  const deliveredCount = practices.filter((p) => p.status === 'delivered').length;
  const avgScore =
    deliveries.length > 0
      ? (
          deliveries.reduce((acc: number, d: any) => acc + (Number(d.self_score) || 0), 0) /
          deliveries.length
        ).toFixed(1)
      : '—';

  const practiceColumns: Column<any>[] = [
    { key: 'event_name', header: 'Event', render: (r: any) => <span className="font-medium">{r.event_name}</span> },
    { key: 'event_date', header: 'Event Date', render: (r: any) => <span>{r.event_date ?? '—'}</span> },
    {
      key: 'practice_session_at',
      header: 'Practiced At',
      render: (r: any) => <span>{r.practice_session_at ? new Date(r.practice_session_at).toLocaleString() : '—'}</span>,
    },
    { key: 'duration_minutes', header: 'Duration (min)', render: (r: any) => <span>{r.duration_minutes ?? 0}</span> },
    {
      key: 'self_score',
      header: 'Self Score',
      render: (r: any) => (
        <span className={r.self_score >= 8 ? 'text-green-600 font-semibold' : r.self_score >= 5 ? 'text-amber-600' : 'text-gray-500'}>
          {r.self_score != null ? `${r.self_score}/10` : '—'}
        </span>
      ),
    },
    {
      key: 'status',
      header: 'Status',
      render: (r: any) => (
        <span
          className={
            r.status === 'delivered'
              ? 'text-green-700'
              : r.status === 'in_progress'
              ? 'text-blue-700'
              : r.status === 'skipped'
              ? 'text-red-700'
              : 'text-gray-700'
          }
        >
          {r.status}
        </span>
      ),
    },
    { key: 'feedback_count', header: 'Feedback', render: (r: any) => <span>{r.feedback_count ?? 0}</span> },
    {
      key: 'recording_url',
      header: 'Recording',
      render: (r: any) =>
        r.recording_url ? (
          <a href={r.recording_url} target="_blank" rel="noreferrer" className="text-blue-600 underline">
            link
          </a>
        ) : (
          <span className="text-gray-400">—</span>
        ),
    },
  ];

  const upcomingColumns: Column<any>[] = [
    { key: 'event_name', header: 'Event', render: (r: any) => <span className="font-medium">{r.event_name}</span> },
    { key: 'event_date', header: 'Event Date', render: (r: any) => <span>{r.event_date ?? '—'}</span> },
    {
      key: 'days_until',
      header: 'Days Until',
      render: (r: any) => (
        <span className={r.days_until <= 3 ? 'text-red-600 font-bold' : r.days_until <= 7 ? 'text-amber-600' : 'text-gray-700'}>
          {r.days_until}d
        </span>
      ),
    },
    {
      key: 'practice_sessions_count',
      header: 'Rehearsals',
      render: (r: any) => <span>{r.practice_sessions_count ?? 0}</span>,
    },
    {
      key: 'latest_self_score',
      header: 'Latest Score',
      render: (r: any) => <span>{r.latest_self_score != null ? `${r.latest_self_score}/10` : '—'}</span>,
    },
    { key: 'status', header: 'Status', render: (r: any) => <span>{r.status}</span> },
  ];

  const deliveriesColumns: Column<any>[] = [
    { key: 'event_name', header: 'Event', render: (r: any) => <span className="font-medium">{r.event_name}</span> },
    { key: 'event_date', header: 'Date', render: (r: any) => <span>{r.event_date ?? '—'}</span> },
    {
      key: 'self_score',
      header: 'Self Score',
      render: (r: any) => (
        <span className={r.self_score >= 8 ? 'text-green-600 font-semibold' : 'text-gray-700'}>
          {r.self_score != null ? `${r.self_score}/10` : '—'}
        </span>
      ),
    },
    { key: 'duration_minutes', header: 'Duration (min)', render: (r: any) => <span>{r.duration_minutes ?? 0}</span> },
    {
      key: 'positive_feedback',
      header: 'Positive Feedback',
      render: (r: any) => (
        <span className="text-green-700">
          {r.positive_feedback ?? 0} / {r.total_feedback ?? 0}
        </span>
      ),
    },
  ];

  const feedbackColumns: Column<any>[] = [
    { key: 'event_name', header: 'Event', render: (r: any) => <span className="font-medium">{r.event_name}</span> },
    { key: 'reviewer_email', header: 'Reviewer', render: (r: any) => <span>{r.reviewer_email}</span> },
    {
      key: 'decision',
      header: 'Decision',
      render: (r: any) => (
        <span
          className={
            r.decision === 'great'
              ? 'text-green-700 font-semibold'
              : r.decision === 'good'
              ? 'text-green-600'
              : r.decision === 'needs_work'
              ? 'text-amber-600'
              : 'text-red-700'
          }
        >
          {r.decision}
        </span>
      ),
    },
    { key: 'decision_note', header: 'Note', render: (r: any) => <span>{r.decision_note ?? '—'}</span> },
    { key: 'at', header: 'At', render: (r: any) => <span>{r.at ? new Date(r.at).toLocaleString() : '—'}</span> },
  ];

  return (
    <div className="p-6 space-y-8">
      <header className="space-y-2">
        <h1 className="text-2xl font-bold">Founder Speaking Practice Log</h1>
        <p className="text-sm text-gray-600">
          Rehearsal log for upcoming speaking engagements. Track practice sessions, self-scores & reviewer feedback before stepping on stage.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="border rounded p-4 bg-white">
          <div className="text-xs text-gray-500 uppercase">Total Sessions</div>
          <div className="text-2xl font-bold">{totalSessions}</div>
        </div>
        <div className="border rounded p-4 bg-white">
          <div className="text-xs text-gray-500 uppercase">Scheduled</div>
          <div className="text-2xl font-bold text-blue-700">{scheduledCount}</div>
        </div>
        <div className="border rounded p-4 bg-white">
          <div className="text-xs text-gray-500 uppercase">Delivered</div>
          <div className="text-2xl font-bold text-green-700">{deliveredCount}</div>
        </div>
        <div className="border rounded p-4 bg-white">
          <div className="text-xs text-gray-500 uppercase">Avg Delivery Score</div>
          <div className="text-2xl font-bold">{avgScore}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Top Upcoming Engagements</h2>
        <p className="text-xs text-gray-500">Events &lt;= 25 ahead, status scheduled or in-progress.</p>
        <DataTable rows={upcoming} columns={upcomingColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Recent Deliveries</h2>
        <p className="text-xs text-gray-500">Most recent 25 talks marked delivered & their positive-feedback ratio.</p>
        <DataTable rows={deliveries} columns={deliveriesColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">All Practice Sessions</h2>
        <p className="text-xs text-gray-500">Latest 200 rehearsals across all events.</p>
        <DataTable rows={practices} columns={practiceColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Recent Reviewer Feedback</h2>
        <p className="text-xs text-gray-500">Latest 300 notes from trusted reviewers — &gt;= great/good or &lt; needs_work/avoid.</p>
        <DataTable rows={feedback} columns={feedbackColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
