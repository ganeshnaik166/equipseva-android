import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [summary, activePairs, recentCheckins, effByGoal, missed, mentorLoad, trend] = await Promise.all([
    sb.rpc('r2258_summary'),
    sb.rpc('r2258_active_pairs'),
    sb.rpc('r2258_recent_checkins', { limit_count: 50 }),
    sb.rpc('r2258_effectiveness_by_goal'),
    sb.rpc('r2258_missed_checkins'),
    sb.rpc('r2258_mentor_load'),
    sb.rpc('r2258_progression_trend'),
  ]);

  const s = summary.data?.[0] ?? {
    active_pairs: 0, paused_pairs: 0, completed_pairs: 0,
    dissolved_pairs: 0, avg_effectiveness: 0, pairs_needing_review: 0,
  };

  const pairCols: Column<any>[] = [
    { key: 'mentor_email', header: 'Mentor', render: (r: any) => r.mentor_email },
    { key: 'mentor_tier', header: 'Mentor Tier', render: (r: any) => r.mentor_tier },
    { key: 'mentee_email', header: 'Mentee', render: (r: any) => r.mentee_email },
    { key: 'mentee_tier', header: 'Mentee Tier', render: (r: any) => r.mentee_tier },
    { key: 'pairing_goal', header: 'Goal', render: (r: any) => r.pairing_goal },
    { key: 'days_paired', header: 'Days Paired', render: (r: any) => r.days_paired },
    { key: 'expected_end_at', header: 'Expected End', render: (r: any) => r.expected_end_at ? new Date(r.expected_end_at).toLocaleDateString() : '-' },
  ];

  const checkinCols: Column<any>[] = [
    { key: 'checkin_month', header: 'Month', render: (r: any) => r.checkin_month },
    { key: 'mentor_email', header: 'Mentor', render: (r: any) => r.mentor_email },
    { key: 'mentee_email', header: 'Mentee', render: (r: any) => r.mentee_email },
    { key: 'checkin_status', header: 'Status', render: (r: any) => r.checkin_status },
    { key: 'mentee_progress_score', header: 'Progress (1-10)', render: (r: any) => r.mentee_progress_score ?? '-' },
    { key: 'topics_covered', header: 'Topics', render: (r: any) => r.topics_covered ?? '-' },
  ];

  const goalCols: Column<any>[] = [
    { key: 'pairing_goal', header: 'Goal', render: (r: any) => r.pairing_goal },
    { key: 'pair_count', header: 'Pairs', render: (r: any) => r.pair_count },
    { key: 'completed_count', header: 'Completed', render: (r: any) => r.completed_count },
    { key: 'avg_effectiveness', header: 'Avg Rating (1-5)', render: (r: any) => r.avg_effectiveness ?? '-' },
  ];

  const missedCols: Column<any>[] = [
    { key: 'checkin_month', header: 'Month', render: (r: any) => r.checkin_month },
    { key: 'mentor_email', header: 'Mentor', render: (r: any) => r.mentor_email },
    { key: 'mentee_email', header: 'Mentee', render: (r: any) => r.mentee_email },
    { key: 'checkin_status', header: 'Status', render: (r: any) => r.checkin_status },
    { key: 'days_overdue', header: 'Days Overdue', render: (r: any) => r.days_overdue },
  ];

  const mentorCols: Column<any>[] = [
    { key: 'mentor_email', header: 'Mentor', render: (r: any) => r.mentor_email },
    { key: 'mentor_tier', header: 'Tier', render: (r: any) => r.mentor_tier },
    { key: 'active_mentees', header: 'Active Mentees', render: (r: any) => r.active_mentees },
    { key: 'completed_mentees', header: 'Completed Mentees', render: (r: any) => r.completed_mentees },
    { key: 'avg_rating', header: 'Avg Rating', render: (r: any) => r.avg_rating ?? '-' },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_bucket', header: 'Month', render: (r: any) => r.month_bucket },
    { key: 'checkins_completed', header: 'Completed', render: (r: any) => r.checkins_completed },
    { key: 'avg_progress_score', header: 'Avg Progress (1-10)', render: (r: any) => r.avg_progress_score ?? '-' },
    { key: 'missed_count', header: 'Missed', render: (r: any) => r.missed_count },
  ];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">Engineer Mentor-Mentee Pairing Tracker</h1>
        <p className="text-sm text-gray-500">Senior & junior pairings, monthly check-ins, mentee progression & pair effectiveness.</p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-6 gap-3">
        <div className="rounded-lg border p-3">
          <div className="text-xs text-gray-500">Active Pairs</div>
          <div className="text-2xl font-semibold">{s.active_pairs}</div>
        </div>
        <div className="rounded-lg border p-3">
          <div className="text-xs text-gray-500">Paused</div>
          <div className="text-2xl font-semibold">{s.paused_pairs}</div>
        </div>
        <div className="rounded-lg border p-3">
          <div className="text-xs text-gray-500">Completed</div>
          <div className="text-2xl font-semibold">{s.completed_pairs}</div>
        </div>
        <div className="rounded-lg border p-3">
          <div className="text-xs text-gray-500">Dissolved</div>
          <div className="text-2xl font-semibold">{s.dissolved_pairs}</div>
        </div>
        <div className="rounded-lg border p-3">
          <div className="text-xs text-gray-500">Avg Effectiveness</div>
          <div className="text-2xl font-semibold">{s.avg_effectiveness ?? '-'}</div>
        </div>
        <div className="rounded-lg border p-3">
          <div className="text-xs text-gray-500">Needing Review (&gt;180d)</div>
          <div className="text-2xl font-semibold">{s.pairs_needing_review}</div>
        </div>
      </div>

      <section>
        <h2 className="text-lg font-medium mb-2">Active Pairs</h2>
        <DataTable columns={pairCols} rows={activePairs.data ?? []} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Recent Check-ins</h2>
        <DataTable columns={checkinCols} rows={recentCheckins.data ?? []} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Effectiveness by Goal</h2>
        <DataTable columns={goalCols} rows={effByGoal.data ?? []} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Missed / Rescheduled Check-ins</h2>
        <DataTable columns={missedCols} rows={missed.data ?? []} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Mentor Load & Performance</h2>
        <DataTable columns={mentorCols} rows={mentorLoad.data ?? []} rowKey={(_, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Monthly Progression Trend</h2>
        <DataTable columns={trendCols} rows={trend.data ?? []} rowKey={(_, i) => String(i)} />
      </section>
    </div>
  );
}
