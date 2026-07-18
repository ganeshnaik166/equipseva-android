import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type QuarterRow = { quarter_label: string; session_count: number; avg_energy: number; avg_stress: number; avg_nps: number; total_fee_rupees: number; closed_commitments: number; total_commitments: number; closure_pct: number };
type TopicRow = { primary_topic: string; session_count: number; avg_nps: number; avg_energy: number; avg_stress: number; closure_pct: number };
type CoachRow = { coach_name: string; coach_firm: string; sessions_held: number; avg_nps: number; total_fee_rupees: number; avg_duration_minutes: number; closure_pct: number };
type CircleRow = { circle_name: string; feedback_count: number; avg_candor: number; avg_usefulness: number; avg_peer_nps: number; recommend_pct: number };
type ActionRow = { action_taken: string; count: number; avg_candor: number; avg_usefulness: number; followup_pct: number };
type BlindRow = { source: string; session_or_feedback_code: string; topic: string; blind_spot: string; action_taken_or_status: string; dt: string };
type StageRow = { peer_ceo_stage: string; feedback_count: number; avg_usefulness: number; accepted_shipped_count: number; rejected_count: number };
type OpenCmtRow = { session_code: string; session_date: string; coach_name: string; primary_topic: string; commitment_count: number; commitments_closed: number; open_commitments: number; next_session_date: string | null };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [quarters, topics, coaches, circles, actions, blinds, stages, openCmts] = await Promise.all([
    supabase.rpc('founder_r3137_quarterly_session_rollup'),
    supabase.rpc('founder_r3137_topic_mix'),
    supabase.rpc('founder_r3137_coach_performance'),
    supabase.rpc('founder_r3137_peer_circle_mix'),
    supabase.rpc('founder_r3137_action_closure_rollup'),
    supabase.rpc('founder_r3137_blind_spots_open'),
    supabase.rpc('founder_r3137_peer_stage_impact'),
    supabase.rpc('founder_r3137_open_commitments_list'),
  ]);

  const quarterCols: Column<QuarterRow>[] = [
    { key: 'quarter_label', header: 'Quarter' },
    { key: 'session_count', header: 'Sessions' },
    { key: 'avg_energy', header: 'Avg Energy (1-10)' },
    { key: 'avg_stress', header: 'Avg Stress (1-10)' },
    { key: 'avg_nps', header: 'Avg NPS' },
    { key: 'total_fee_rupees', header: 'Fees (INR)' },
    { key: 'closed_commitments', header: 'Closed Commitments' },
    { key: 'total_commitments', header: 'Total Commitments' },
    { key: 'closure_pct', header: 'Closure %' },
  ];

  const topicCols: Column<TopicRow>[] = [
    { key: 'primary_topic', header: 'Topic' },
    { key: 'session_count', header: 'Sessions' },
    { key: 'avg_nps', header: 'Avg NPS' },
    { key: 'avg_energy', header: 'Avg Energy' },
    { key: 'avg_stress', header: 'Avg Stress' },
    { key: 'closure_pct', header: 'Closure %' },
  ];

  const coachCols: Column<CoachRow>[] = [
    { key: 'coach_name', header: 'Coach' },
    { key: 'coach_firm', header: 'Firm' },
    { key: 'sessions_held', header: 'Sessions' },
    { key: 'avg_nps', header: 'Avg NPS' },
    { key: 'total_fee_rupees', header: 'Total Fees (INR)' },
    { key: 'avg_duration_minutes', header: 'Avg Duration (min)' },
    { key: 'closure_pct', header: 'Closure %' },
  ];

  const circleCols: Column<CircleRow>[] = [
    { key: 'circle_name', header: 'Peer CEO Circle' },
    { key: 'feedback_count', header: 'Feedback Count' },
    { key: 'avg_candor', header: 'Avg Candor' },
    { key: 'avg_usefulness', header: 'Avg Usefulness' },
    { key: 'avg_peer_nps', header: 'Avg Peer NPS' },
    { key: 'recommend_pct', header: 'Would Recommend %' },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'action_taken', header: 'Action Taken' },
    { key: 'count', header: 'Count' },
    { key: 'avg_candor', header: 'Avg Candor' },
    { key: 'avg_usefulness', header: 'Avg Usefulness' },
    { key: 'followup_pct', header: 'Followup %' },
  ];

  const blindCols: Column<BlindRow>[] = [
    { key: 'source', header: 'Source' },
    { key: 'session_or_feedback_code', header: 'Code' },
    { key: 'topic', header: 'Topic' },
    { key: 'blind_spot', header: 'Blind Spot' },
    { key: 'action_taken_or_status', header: 'Status / Action' },
    { key: 'dt', header: 'Date' },
  ];

  const stageCols: Column<StageRow>[] = [
    { key: 'peer_ceo_stage', header: 'Peer Stage' },
    { key: 'feedback_count', header: 'Feedback Count' },
    { key: 'avg_usefulness', header: 'Avg Usefulness' },
    { key: 'accepted_shipped_count', header: 'Accepted & Shipped' },
    { key: 'rejected_count', header: 'Rejected' },
  ];

  const openCmtCols: Column<OpenCmtRow>[] = [
    { key: 'session_code', header: 'Session' },
    { key: 'session_date', header: 'Date' },
    { key: 'coach_name', header: 'Coach' },
    { key: 'primary_topic', header: 'Topic' },
    { key: 'commitment_count', header: 'Total' },
    { key: 'commitments_closed', header: 'Closed' },
    { key: 'open_commitments', header: 'Open' },
    { key: 'next_session_date', header: 'Next Session' },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '8px' }}>
        Founder Executive Coach & Peer-CEO Circle Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '24px' }}>
        Quarterly coaching cadence, peer CEO feedback candor, blind-spot log and commitment closure &gt;= 80% target.
      </p>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Quarterly Session Rollup</h2>
        <DataTable
          rows={(quarters.data ?? []) as QuarterRow[]}
          columns={quarterCols}
          emptyMessage="No coach sessions logged"
          rowKey={(r, i) => String((r as QuarterRow).quarter_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Topic Mix (avg NPS & stress by topic)</h2>
        <DataTable
          rows={(topics.data ?? []) as TopicRow[]}
          columns={topicCols}
          emptyMessage="No topic data"
          rowKey={(r, i) => String((r as TopicRow).primary_topic ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Coach Performance</h2>
        <DataTable
          rows={(coaches.data ?? []) as CoachRow[]}
          columns={coachCols}
          emptyMessage="No coach data"
          rowKey={(r, i) => String((r as CoachRow).coach_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Peer CEO Circle Mix</h2>
        <DataTable
          rows={(circles.data ?? []) as CircleRow[]}
          columns={circleCols}
          emptyMessage="No peer circle feedback"
          rowKey={(r, i) => String((r as CircleRow).circle_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Action Closure by Verdict</h2>
        <DataTable
          rows={(actions.data ?? []) as ActionRow[]}
          columns={actionCols}
          emptyMessage="No action data"
          rowKey={(r, i) => String((r as ActionRow).action_taken ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Blind Spots Log (coach + peer)</h2>
        <DataTable
          rows={(blinds.data ?? []) as BlindRow[]}
          columns={blindCols}
          emptyMessage="No blind spots surfaced"
          rowKey={(r, i) => String((r as BlindRow).session_or_feedback_code ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Peer Stage Impact (usefulness & ship-rate)</h2>
        <DataTable
          rows={(stages.data ?? []) as StageRow[]}
          columns={stageCols}
          emptyMessage="No peer stage data"
          rowKey={(r, i) => String((r as StageRow).peer_ceo_stage ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Open Commitments Follow-Up</h2>
        <DataTable
          rows={(openCmts.data ?? []) as OpenCmtRow[]}
          columns={openCmtCols}
          emptyMessage="No open commitments"
          rowKey={(r, i) => String((r as OpenCmtRow).session_code ?? i)}
        />
      </section>
    </main>
  );
}
