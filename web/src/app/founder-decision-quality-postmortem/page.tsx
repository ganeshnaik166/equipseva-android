import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderDecisionQualityPostmortemPage() {
  const supabase = await getSupabaseServerClient();

  const [
    decisionsRes,
    sessionsRes,
    kindRes,
    deltaRes,
    lessonsRes,
    repeatRes,
    trendRes,
  ] = await Promise.all([
    supabase.rpc('list_decisions_r2466'),
    supabase.rpc('list_review_sessions_r2466'),
    supabase.rpc('decision_kind_breakdown_r2466'),
    supabase.rpc('delta_distribution_r2466'),
    supabase.rpc('top_lessons_r2466'),
    supabase.rpc('repeat_patterns_r2466'),
    supabase.rpc('monthly_postmortem_trend_r2466'),
  ]);

  const decisions = (decisionsRes.data ?? []) as any[];
  const sessions = (sessionsRes.data ?? []) as any[];
  const kindBreakdown = (kindRes.data ?? []) as any[];
  const deltaDist = (deltaRes.data ?? []) as any[];
  const lessons = (lessonsRes.data ?? []) as any[];
  const repeats = (repeatRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];

  const decisionsCols: Column<any>[] = [
    { key: 'decision_name', header: 'Decision', render: (r: any) => r.decision_name },
    { key: 'decision_kind', header: 'Kind', render: (r: any) => r.decision_kind },
    { key: 'decided_at', header: 'Decided', render: (r: any) => new Date(r.decided_at).toLocaleDateString() },
    { key: 'delta_kind', header: 'Delta', render: (r: any) => r.delta_kind },
    { key: 'delta_summary', header: 'Summary', render: (r: any) => r.delta_summary },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const sessionsCols: Column<any>[] = [
    { key: 'reviewed_at', header: 'Reviewed', render: (r: any) => new Date(r.reviewed_at).toLocaleDateString() },
    { key: 'reviewer_email', header: 'Reviewer', render: (r: any) => r.reviewer_email },
    { key: 'decisions_reviewed_count', header: 'Reviewed', render: (r: any) => r.decisions_reviewed_count },
    { key: 'top_win', header: 'Top Win', render: (r: any) => r.top_win },
    { key: 'top_miss', header: 'Top Miss', render: (r: any) => r.top_miss },
    { key: 'top_lesson', header: 'Top Lesson', render: (r: any) => r.top_lesson },
    { key: 'repeat_pattern_count', header: 'Repeats', render: (r: any) => r.repeat_pattern_count },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const kindCols: Column<any>[] = [
    { key: 'decision_kind', header: 'Kind', render: (r: any) => r.decision_kind },
    { key: 'count_total', header: 'Total', render: (r: any) => r.count_total },
    { key: 'count_better', header: 'Better', render: (r: any) => r.count_better },
    { key: 'count_worse', header: 'Worse', render: (r: any) => r.count_worse },
  ];

  const deltaCols: Column<any>[] = [
    { key: 'delta_kind', header: 'Delta', render: (r: any) => r.delta_kind },
    { key: 'count_total', header: 'Count', render: (r: any) => r.count_total },
    { key: 'pct', header: 'Pct', render: (r: any) => `${r.pct}%` },
  ];

  const lessonsCols: Column<any>[] = [
    { key: 'decision_name', header: 'Decision', render: (r: any) => r.decision_name },
    { key: 'decision_kind', header: 'Kind', render: (r: any) => r.decision_kind },
    { key: 'delta_kind', header: 'Delta', render: (r: any) => r.delta_kind },
    { key: 'lesson_md', header: 'Lesson', render: (r: any) => r.lesson_md },
  ];

  const repeatsCols: Column<any>[] = [
    { key: 'decision_kind', header: 'Kind', render: (r: any) => r.decision_kind },
    { key: 'miss_count', header: 'Misses', render: (r: any) => r.miss_count },
    { key: 'latest_lesson', header: 'Latest Lesson', render: (r: any) => r.latest_lesson },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => new Date(r.month_start).toLocaleDateString() },
    { key: 'decisions_count', header: 'Decisions', render: (r: any) => r.decisions_count },
    { key: 'better_count', header: 'Better', render: (r: any) => r.better_count },
    { key: 'worse_count', header: 'Worse', render: (r: any) => r.worse_count },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Founder Decision-Quality Post-Mortem</h1>
        <p className="text-sm text-gray-600">
          Decision &gt; hypothesis &gt; actual outcome &gt; delta &gt; root cause &gt; lesson &gt; repeat-avoidance.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Decisions</h2>
        <DataTable
          rows={decisions}
          columns={decisionsCols}
          emptyMessage="No decisions logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Review Sessions</h2>
        <DataTable
          rows={sessions}
          columns={sessionsCols}
          emptyMessage="No review sessions."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Decision Kind Breakdown</h2>
        <DataTable
          rows={kindBreakdown}
          columns={kindCols}
          emptyMessage="No data."
          rowKey={(r: any, i: number) => String(r.decision_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Delta Distribution</h2>
        <DataTable
          rows={deltaDist}
          columns={deltaCols}
          emptyMessage="No data."
          rowKey={(r: any, i: number) => String(r.delta_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Lessons</h2>
        <DataTable
          rows={lessons}
          columns={lessonsCols}
          emptyMessage="No lessons."
          rowKey={(r: any, i: number) => String(r.decision_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Repeat Patterns</h2>
        <DataTable
          rows={repeats}
          columns={repeatsCols}
          emptyMessage="No repeat patterns."
          rowKey={(r: any, i: number) => String(r.decision_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Post-Mortem Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>
    </div>
  );
}
