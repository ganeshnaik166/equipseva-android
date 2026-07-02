import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type MentorRow = {
  id: string;
  mentor_name: string;
  mentor_type: string;
  company_or_role: string;
  relationship_status: string;
  expertise_tags: string;
  first_met_on: string | null;
  session_count: number;
  last_session_on: string | null;
};

type SessionRow = {
  id: string;
  mentor_id: string;
  mentor_name: string;
  session_date: string;
  session_format: string;
  duration_minutes: number;
  topic_summary: string;
  action_status: string;
  usefulness_rating: number | null;
  follow_up_due_date: string | null;
};

type FollowUpRow = {
  id: string;
  mentor_id: string;
  mentor_name: string;
  session_date: string;
  topic_summary: string;
  action_status: string;
  follow_up_due_date: string | null;
  days_until_due: number;
};

type HighRatedRow = {
  id: string;
  mentor_name: string;
  mentor_type: string;
  session_date: string;
  topic_summary: string;
  usefulness_rating: number;
  action_status: string;
};

type SummaryRow = {
  mentor_id: string;
  mentor_name: string;
  mentor_type: string;
  total_sessions: number;
  total_minutes: number;
  pending_actions: number;
  done_actions: number;
  avg_usefulness: number | null;
};

type TypeRow = {
  mentor_type: string;
  mentor_count: number;
  session_count: number;
  total_minutes: number;
  avg_rating: number | null;
};

type CadenceRow = {
  month_start: string;
  session_count: number;
  unique_mentors: number;
  total_minutes: number;
  done_count: number;
  avg_rating: number | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [mentorsRes, sessionsRes, followUpsRes, highRatedRes, summaryRes, typeRes, cadenceRes] = await Promise.all([
    sb.rpc('list_mentors_r2313'),
    sb.rpc('list_sessions_r2313'),
    sb.rpc('pending_follow_ups_r2313'),
    sb.rpc('high_rated_advice_r2313'),
    sb.rpc('mentor_summary_r2313'),
    sb.rpc('type_breakdown_r2313'),
    sb.rpc('monthly_cadence_r2313'),
  ]);

  const mentors: MentorRow[] = (mentorsRes.data as MentorRow[] | null) ?? [];
  const sessions: SessionRow[] = (sessionsRes.data as SessionRow[] | null) ?? [];
  const followUps: FollowUpRow[] = (followUpsRes.data as FollowUpRow[] | null) ?? [];
  const highRated: HighRatedRow[] = (highRatedRes.data as HighRatedRow[] | null) ?? [];
  const summary: SummaryRow[] = (summaryRes.data as SummaryRow[] | null) ?? [];
  const typeBreakdown: TypeRow[] = (typeRes.data as TypeRow[] | null) ?? [];
  const cadence: CadenceRow[] = (cadenceRes.data as CadenceRow[] | null) ?? [];

  const mentorCols: Column<MentorRow>[] = [
    { key: 'mentor_name', header: 'Mentor', render: (r: any) => r.mentor_name },
    { key: 'mentor_type', header: 'Type', render: (r: any) => r.mentor_type },
    { key: 'company_or_role', header: 'Company / Role', render: (r: any) => r.company_or_role || '—' },
    { key: 'expertise_tags', header: 'Expertise', render: (r: any) => r.expertise_tags || '—' },
    { key: 'relationship_status', header: 'Status', render: (r: any) => r.relationship_status },
    { key: 'first_met_on', header: 'First met', render: (r: any) => r.first_met_on ?? '—' },
    { key: 'session_count', header: 'Sessions', render: (r: any) => r.session_count },
    { key: 'last_session_on', header: 'Last session', render: (r: any) => r.last_session_on ?? '—' },
  ];

  const sessionCols: Column<SessionRow>[] = [
    { key: 'session_date', header: 'Date', render: (r: any) => r.session_date },
    { key: 'mentor_name', header: 'Mentor', render: (r: any) => r.mentor_name },
    { key: 'session_format', header: 'Format', render: (r: any) => r.session_format },
    { key: 'duration_minutes', header: 'Min', render: (r: any) => r.duration_minutes },
    { key: 'topic_summary', header: 'Topic', render: (r: any) => r.topic_summary },
    { key: 'action_status', header: 'Action', render: (r: any) => r.action_status },
    { key: 'usefulness_rating', header: 'Rating', render: (r: any) => r.usefulness_rating ?? '—' },
    { key: 'follow_up_due_date', header: 'Follow-up', render: (r: any) => r.follow_up_due_date ?? '—' },
  ];

  const followUpCols: Column<FollowUpRow>[] = [
    { key: 'follow_up_due_date', header: 'Due', render: (r: any) => r.follow_up_due_date ?? '—' },
    { key: 'days_until_due', header: 'Days', render: (r: any) => r.days_until_due },
    { key: 'mentor_name', header: 'Mentor', render: (r: any) => r.mentor_name },
    { key: 'session_date', header: 'Session', render: (r: any) => r.session_date },
    { key: 'topic_summary', header: 'Topic', render: (r: any) => r.topic_summary },
    { key: 'action_status', header: 'Status', render: (r: any) => r.action_status },
  ];

  const highRatedCols: Column<HighRatedRow>[] = [
    { key: 'usefulness_rating', header: 'Rating', render: (r: any) => r.usefulness_rating },
    { key: 'mentor_name', header: 'Mentor', render: (r: any) => r.mentor_name },
    { key: 'mentor_type', header: 'Type', render: (r: any) => r.mentor_type },
    { key: 'session_date', header: 'Date', render: (r: any) => r.session_date },
    { key: 'topic_summary', header: 'Topic', render: (r: any) => r.topic_summary },
    { key: 'action_status', header: 'Action', render: (r: any) => r.action_status },
  ];

  const summaryCols: Column<SummaryRow>[] = [
    { key: 'mentor_name', header: 'Mentor', render: (r: any) => r.mentor_name },
    { key: 'mentor_type', header: 'Type', render: (r: any) => r.mentor_type },
    { key: 'total_sessions', header: 'Sessions', render: (r: any) => r.total_sessions },
    { key: 'total_minutes', header: 'Minutes', render: (r: any) => r.total_minutes },
    { key: 'pending_actions', header: 'Pending', render: (r: any) => r.pending_actions },
    { key: 'done_actions', header: 'Done', render: (r: any) => r.done_actions },
    { key: 'avg_usefulness', header: 'Avg rating', render: (r: any) => r.avg_usefulness ?? '—' },
  ];

  const typeCols: Column<TypeRow>[] = [
    { key: 'mentor_type', header: 'Type', render: (r: any) => r.mentor_type },
    { key: 'mentor_count', header: 'Mentors', render: (r: any) => r.mentor_count },
    { key: 'session_count', header: 'Sessions', render: (r: any) => r.session_count },
    { key: 'total_minutes', header: 'Minutes', render: (r: any) => r.total_minutes },
    { key: 'avg_rating', header: 'Avg rating', render: (r: any) => r.avg_rating ?? '—' },
  ];

  const cadenceCols: Column<CadenceRow>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => r.month_start },
    { key: 'session_count', header: 'Sessions', render: (r: any) => r.session_count },
    { key: 'unique_mentors', header: 'Mentors', render: (r: any) => r.unique_mentors },
    { key: 'total_minutes', header: 'Minutes', render: (r: any) => r.total_minutes },
    { key: 'done_count', header: 'Done', render: (r: any) => r.done_count },
    { key: 'avg_rating', header: 'Avg rating', render: (r: any) => r.avg_rating ?? '—' },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>External Mentor Session Log</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Sessions with industry vets and fellow founders. Track advice given =&gt; action taken =&gt; outcome, plus follow-ups and usefulness ratings.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Mentors ({mentors.length})</h2>
        <DataTable
          rows={mentors}
          columns={mentorCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No mentors logged yet."
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Sessions ({sessions.length})</h2>
        <DataTable
          rows={sessions}
          columns={sessionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No sessions logged."
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Pending follow-ups ({followUps.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Sessions with action_status pending or in_progress and follow_up_due_date set. Negative days =&gt; overdue.
        </p>
        <DataTable
          rows={followUps}
          columns={followUpCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No pending follow-ups."
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>High-rated advice ({highRated.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Sessions rated 4 or 5 out of 5 for usefulness. Re-read before next strategic decision.
        </p>
        <DataTable
          rows={highRated}
          columns={highRatedCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No high-rated sessions yet."
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Per-mentor summary ({summary.length})</h2>
        <DataTable
          rows={summary}
          columns={summaryCols}
          rowKey={(r: any, i: number) => String(r.mentor_id ?? i)}
          emptyMessage="No mentor summary."
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Type breakdown ({typeBreakdown.length})</h2>
        <DataTable
          rows={typeBreakdown}
          columns={typeCols}
          rowKey={(r: any, i: number) => String(r.mentor_type ?? i)}
          emptyMessage="No type breakdown."
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Monthly cadence ({cadence.length})</h2>
        <DataTable
          rows={cadence}
          columns={cadenceCols}
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
          emptyMessage="No cadence data."
        />
      </section>
    </div>
  );
}
