import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderWeeklyPrioritizationStackPage() {
  const supabase = await getSupabaseServerClient();

  const [priorities, reviews, currentFocus, completionRate, topRoi, blocked, monthlyPulse] = await Promise.all([
    supabase.rpc('list_priorities_r2445'),
    supabase.rpc('list_reviews_r2445'),
    supabase.rpc('current_week_focus_r2445'),
    supabase.rpc('weekly_completion_rate_r2445'),
    supabase.rpc('top_roi_completed_r2445'),
    supabase.rpc('blocked_focus_r2445'),
    supabase.rpc('monthly_review_pulse_r2445'),
  ]);

  const fmtRupees = (n: number | null | undefined) =>
    n == null ? '-' : `Rs ${Number(n).toLocaleString('en-IN')}`;
  const fmtDate = (s: string | null | undefined) =>
    s ? new Date(s).toLocaleDateString('en-IN') : '-';
  const fmtDt = (s: string | null | undefined) =>
    s ? new Date(s).toLocaleString('en-IN') : '-';

  const statusBadge = (s: string) => {
    const map: Record<string, string> = {
      not_started: 'bg-gray-100 text-gray-700',
      in_progress: 'bg-blue-100 text-blue-800',
      blocked: 'bg-red-100 text-red-800',
      done: 'bg-green-100 text-green-800',
      dropped: 'bg-yellow-100 text-yellow-800',
    };
    return (
      <span className={`px-2 py-0.5 rounded text-xs font-medium ${map[s] ?? 'bg-gray-100 text-gray-700'}`}>
        {s}
      </span>
    );
  };

  const prioritiesCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => fmtDate(r.week_start) },
    { key: 'rank', header: 'Rank', render: (r: any) => `#${r.rank}` },
    { key: 'title', header: 'Title', render: (r: any) => r.title },
    { key: 'status', header: 'Status', render: (r: any) => statusBadge(r.status) },
    { key: 'estimated_roi_rupees', header: 'Est. ROI', render: (r: any) => fmtRupees(r.estimated_roi_rupees) },
    { key: 'effort_hours', header: 'Effort (hrs)', render: (r: any) => r.effort_hours },
    { key: 'completed_at', header: 'Completed', render: (r: any) => fmtDt(r.completed_at) },
    { key: 'blocker_notes', header: 'Blocker', render: (r: any) => r.blocker_notes ?? '-' },
  ];

  const reviewsCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => fmtDate(r.week_start) },
    { key: 'started_count', header: 'Started', render: (r: any) => r.started_count },
    { key: 'done_count', header: 'Done', render: (r: any) => r.done_count },
    { key: 'blocked_count', header: 'Blocked', render: (r: any) => r.blocked_count },
    { key: 'dropped_count', header: 'Dropped', render: (r: any) => r.dropped_count },
    { key: 'total_roi_realized_rupees', header: 'ROI Realized', render: (r: any) => fmtRupees(r.total_roi_realized_rupees) },
    { key: 'total_hours_spent', header: 'Hours', render: (r: any) => r.total_hours_spent },
    { key: 'top_win', header: 'Top Win', render: (r: any) => r.top_win ?? '-' },
    { key: 'top_miss', header: 'Top Miss', render: (r: any) => r.top_miss ?? '-' },
  ];

  const currentCols: Column<any>[] = [
    { key: 'rank', header: 'Rank', render: (r: any) => `#${r.rank}` },
    { key: 'title', header: 'Title', render: (r: any) => r.title },
    { key: 'status', header: 'Status', render: (r: any) => statusBadge(r.status) },
    { key: 'estimated_roi_rupees', header: 'Est. ROI', render: (r: any) => fmtRupees(r.estimated_roi_rupees) },
    { key: 'effort_hours', header: 'Effort', render: (r: any) => `${r.effort_hours}h` },
    { key: 'blocker_notes', header: 'Blocker', render: (r: any) => r.blocker_notes ?? '-' },
  ];

  const completionCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => fmtDate(r.week_start) },
    { key: 'total_priorities', header: 'Total', render: (r: any) => r.total_priorities },
    { key: 'done_count', header: 'Done', render: (r: any) => r.done_count },
    { key: 'completion_pct', header: 'Completion %', render: (r: any) => `${r.completion_pct ?? 0}%` },
  ];

  const topRoiCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => fmtDate(r.week_start) },
    { key: 'rank', header: 'Rank', render: (r: any) => `#${r.rank}` },
    { key: 'title', header: 'Title', render: (r: any) => r.title },
    { key: 'estimated_roi_rupees', header: 'ROI', render: (r: any) => fmtRupees(r.estimated_roi_rupees) },
    { key: 'effort_hours', header: 'Effort', render: (r: any) => `${r.effort_hours}h` },
    { key: 'completed_at', header: 'Completed', render: (r: any) => fmtDt(r.completed_at) },
  ];

  const blockedCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => fmtDate(r.week_start) },
    { key: 'rank', header: 'Rank', render: (r: any) => `#${r.rank}` },
    { key: 'title', header: 'Title', render: (r: any) => r.title },
    { key: 'estimated_roi_rupees', header: 'ROI at Risk', render: (r: any) => fmtRupees(r.estimated_roi_rupees) },
    { key: 'days_blocked', header: 'Days Blocked', render: (r: any) => r.days_blocked },
    { key: 'blocker_notes', header: 'Reason', render: (r: any) => r.blocker_notes ?? '-' },
  ];

  const monthlyCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => fmtDate(r.month_start) },
    { key: 'weeks_count', header: 'Weeks', render: (r: any) => r.weeks_count },
    { key: 'total_started', header: 'Started', render: (r: any) => r.total_started },
    { key: 'total_done', header: 'Done', render: (r: any) => r.total_done },
    { key: 'total_blocked', header: 'Blocked', render: (r: any) => r.total_blocked },
    { key: 'total_dropped', header: 'Dropped', render: (r: any) => r.total_dropped },
    { key: 'total_roi_realized_rupees', header: 'ROI Realized', render: (r: any) => fmtRupees(r.total_roi_realized_rupees) },
    { key: 'avg_completion_pct', header: 'Avg Completion %', render: (r: any) => `${r.avg_completion_pct ?? 0}%` },
  ];

  return (
    <div className="p-6 space-y-8 max-w-7xl mx-auto">
      <header>
        <h1 className="text-3xl font-bold mb-2">Founder Weekly Prioritization Stack</h1>
        <p className="text-gray-600">
          Top 5 priorities each week & track started =&gt; done/blocked/dropped & realized ROI vs effort
        </p>
      </header>

      <section>
        <h2 className="text-xl font-semibold mb-3">Current Week Focus</h2>
        <DataTable
          rows={currentFocus.data ?? []}
          columns={currentCols}
          emptyMessage="No current week priorities set"
          rowKey={(r: any, i: number) => String(r.id ?? `${r.week_start}-${r.rank}` ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Weekly Completion Rate</h2>
        <DataTable
          rows={completionRate.data ?? []}
          columns={completionCols}
          emptyMessage="No completion data yet"
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Top ROI Completed</h2>
        <DataTable
          rows={topRoi.data ?? []}
          columns={topRoiCols}
          emptyMessage="No completed priorities yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Blocked & At-Risk ROI</h2>
        <DataTable
          rows={blocked.data ?? []}
          columns={blockedCols}
          emptyMessage="Nothing blocked - clean board"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">All Priorities</h2>
        <DataTable
          rows={priorities.data ?? []}
          columns={prioritiesCols}
          emptyMessage="No priorities logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Weekly Reviews</h2>
        <DataTable
          rows={reviews.data ?? []}
          columns={reviewsCols}
          emptyMessage="No weekly reviews logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Monthly Review Pulse</h2>
        <DataTable
          rows={monthlyPulse.data ?? []}
          columns={monthlyCols}
          emptyMessage="No monthly data yet"
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>
    </div>
  );
}
