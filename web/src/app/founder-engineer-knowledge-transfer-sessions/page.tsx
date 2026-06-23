import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerKnowledgeTransferSessionsPage() {
  const supabase = await getSupabaseServerClient();

  const [
    sessionsRes,
    assessmentsRes,
    trainersRes,
    topicsRes,
    gainRes,
    trendRes,
    topJuniorsRes,
  ] = await Promise.all([
    supabase.rpc('list_kt_sessions_r2518'),
    supabase.rpc('list_assessments_r2518'),
    supabase.rpc('top_senior_trainers_r2518'),
    supabase.rpc('topic_kind_breakdown_r2518'),
    supabase.rpc('knowledge_gain_distribution_r2518'),
    supabase.rpc('monthly_session_trend_r2518'),
    supabase.rpc('top_juniors_progress_r2518'),
  ]);

  const sessions = sessionsRes.data ?? [];
  const assessments = assessmentsRes.data ?? [];
  const trainers = trainersRes.data ?? [];
  const topics = topicsRes.data ?? [];
  const gain = gainRes.data ?? [];
  const trend = trendRes.data ?? [];
  const topJuniors = topJuniorsRes.data ?? [];

  const sessionCols: Column<any>[] = [
    { key: 'session_at', header: 'When', render: (r: any) => new Date(r.session_at).toLocaleDateString() },
    { key: 'topic_kind', header: 'Topic Kind', render: (r: any) => r.topic_kind },
    { key: 'topic_summary', header: 'Topic', render: (r: any) => r.topic_summary },
    { key: 'duration_minutes', header: 'Mins', render: (r: any) => String(r.duration_minutes) },
    { key: 'juniors_attended', header: 'Juniors', render: (r: any) => String(r.juniors_attended) },
    { key: 'attendance_score', header: 'Attend %', render: (r: any) => String(r.attendance_score) },
    { key: 'feedback_score', header: 'Feedback /10', render: (r: any) => String(r.feedback_score) },
    { key: 'knowledge_gain_assessment', header: 'Gain', render: (r: any) => r.knowledge_gain_assessment },
    { key: 'avg_gain_delta', header: 'Avg Delta', render: (r: any) => String(r.avg_gain_delta) },
    { key: 'assessment_count', header: 'Assessments', render: (r: any) => String(r.assessment_count) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const assessmentCols: Column<any>[] = [
    { key: 'session_at', header: 'When', render: (r: any) => new Date(r.session_at).toLocaleDateString() },
    { key: 'topic_kind', header: 'Topic Kind', render: (r: any) => r.topic_kind },
    { key: 'topic_summary', header: 'Topic', render: (r: any) => r.topic_summary },
    { key: 'pre_score', header: 'Pre', render: (r: any) => String(r.pre_score) },
    { key: 'post_score', header: 'Post', render: (r: any) => String(r.post_score) },
    { key: 'gain_delta', header: 'Delta', render: (r: any) => String(r.gain_delta) },
    { key: 'confidence_kind', header: 'Confidence', render: (r: any) => r.confidence_kind },
    { key: 'follow_up_required', header: 'Follow-up', render: (r: any) => (r.follow_up_required ? 'yes' : 'no') },
    { key: 'follow_up_at', header: 'Follow-up When', render: (r: any) => (r.follow_up_at ? new Date(r.follow_up_at).toLocaleDateString() : '—') },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const trainerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Trainer', render: (r: any) => r.owner_email },
    { key: 'sessions_count', header: 'Sessions', render: (r: any) => String(r.sessions_count) },
    { key: 'juniors_trained', header: 'Juniors', render: (r: any) => String(r.juniors_trained) },
    { key: 'avg_feedback_score', header: 'Avg Feedback', render: (r: any) => String(r.avg_feedback_score) },
    { key: 'avg_attendance', header: 'Avg Attend %', render: (r: any) => String(r.avg_attendance) },
    { key: 'transformative_count', header: 'Transformative', render: (r: any) => String(r.transformative_count) },
  ];

  const topicCols: Column<any>[] = [
    { key: 'topic_kind', header: 'Topic Kind', render: (r: any) => r.topic_kind },
    { key: 'sessions_count', header: 'Sessions', render: (r: any) => String(r.sessions_count) },
    { key: 'juniors_total', header: 'Juniors', render: (r: any) => String(r.juniors_total) },
    { key: 'avg_feedback', header: 'Avg Feedback', render: (r: any) => String(r.avg_feedback) },
    { key: 'avg_gain_delta', header: 'Avg Delta', render: (r: any) => String(r.avg_gain_delta) },
  ];

  const gainCols: Column<any>[] = [
    { key: 'knowledge_gain_assessment', header: 'Gain Assessment', render: (r: any) => r.knowledge_gain_assessment },
    { key: 'sessions_count', header: 'Sessions', render: (r: any) => String(r.sessions_count) },
    { key: 'juniors_total', header: 'Juniors', render: (r: any) => String(r.juniors_total) },
    { key: 'avg_feedback', header: 'Avg Feedback', render: (r: any) => String(r.avg_feedback) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'sessions_count', header: 'Sessions', render: (r: any) => String(r.sessions_count) },
    { key: 'juniors_total', header: 'Juniors', render: (r: any) => String(r.juniors_total) },
    { key: 'avg_feedback', header: 'Avg Feedback', render: (r: any) => String(r.avg_feedback) },
    { key: 'follow_ups_needed', header: 'Follow-ups', render: (r: any) => String(r.follow_ups_needed) },
  ];

  const topJuniorCols: Column<any>[] = [
    { key: 'session_at', header: 'When', render: (r: any) => new Date(r.session_at).toLocaleDateString() },
    { key: 'topic_summary', header: 'Topic', render: (r: any) => r.topic_summary },
    { key: 'topic_kind', header: 'Kind', render: (r: any) => r.topic_kind },
    { key: 'pre_score', header: 'Pre', render: (r: any) => String(r.pre_score) },
    { key: 'post_score', header: 'Post', render: (r: any) => String(r.post_score) },
    { key: 'gain_delta', header: 'Delta', render: (r: any) => String(r.gain_delta) },
    { key: 'confidence_kind', header: 'Confidence', render: (r: any) => r.confidence_kind },
    { key: 'follow_up_required', header: 'Follow-up', render: (r: any) => (r.follow_up_required ? 'yes' : 'no') },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Knowledge Transfer Sessions</h1>
        <p className="text-sm text-gray-600">
          Senior-to-junior knowledge transfer — attendance, feedback, topic mix, and per-junior pre/post gain.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Sessions</h2>
        <DataTable
          rows={sessions}
          columns={sessionCols}
          emptyMessage="No KT sessions logged yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Senior Trainers</h2>
        <DataTable
          rows={trainers}
          columns={trainerCols}
          emptyMessage="No trainer activity."
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Topic Kind Breakdown</h2>
        <DataTable
          rows={topics}
          columns={topicCols}
          emptyMessage="No topic data."
          rowKey={(r: any, i: number) => String(r.topic_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Knowledge Gain Distribution</h2>
        <DataTable
          rows={gain}
          columns={gainCols}
          emptyMessage="No gain data."
          rowKey={(r: any, i: number) => String(r.knowledge_gain_assessment ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Session Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Per-Junior Assessments</h2>
        <DataTable
          rows={assessments}
          columns={assessmentCols}
          emptyMessage="No assessments recorded."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Junior Progress (by Gain Delta)</h2>
        <DataTable
          rows={topJuniors}
          columns={topJuniorCols}
          emptyMessage="No junior progress data."
          rowKey={(r: any, i: number) => String(r.assessment_id ?? i)}
        />
      </section>
    </main>
  );
}
