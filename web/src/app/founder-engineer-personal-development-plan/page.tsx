import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function EngineerPersonalDevelopmentPlanPage() {
  const supabase = await getSupabaseServerClient();

  const [goalsRes, milestonesRes, topReadyRes, overdueRes, managerLoadRes, completionRes, trackDistRes] = await Promise.all([
    supabase.rpc('list_pdp_goals_r2478'),
    supabase.rpc('list_milestones_r2478'),
    supabase.rpc('top_promotion_ready_r2478'),
    supabase.rpc('overdue_milestones_r2478'),
    supabase.rpc('manager_load_r2478'),
    supabase.rpc('completion_rate_r2478'),
    supabase.rpc('career_track_distribution_r2478'),
  ]);

  const goals = (goalsRes.data as any[]) ?? [];
  const milestones = (milestonesRes.data as any[]) ?? [];
  const topReady = (topReadyRes.data as any[]) ?? [];
  const overdue = (overdueRes.data as any[]) ?? [];
  const managerLoad = (managerLoadRes.data as any[]) ?? [];
  const completion = (completionRes.data as any[]) ?? [];
  const trackDist = (trackDistRes.data as any[]) ?? [];

  const c = completion[0] ?? { total_milestones: 0, done_count: 0, blocked_count: 0, in_progress_count: 0, completion_pct: 0 };

  const fmtDate = (v: any) => (v ? new Date(v).toLocaleDateString() : '-');

  const goalCols: Column<any>[] = [
    { key: 'goal_title', header: 'Goal', render: (r: any) => <span className="font-medium">{r.goal_title}</span> },
    { key: 'career_track', header: 'Track', render: (r: any) => <span className="text-xs uppercase tracking-wide">{r.career_track}</span> },
    { key: 'promotion_readiness_pct', header: 'Readiness', render: (r: any) => <span className="font-mono">{r.promotion_readiness_pct}%</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="text-xs">{r.status}</span> },
    { key: 'manager_email', header: 'Manager', render: (r: any) => <span className="text-xs">{r.manager_email ?? '-'}</span> },
    { key: 'last_check_in_at', header: 'Last Check-in', render: (r: any) => <span className="text-xs">{fmtDate(r.last_check_in_at)}</span> },
    { key: 'next_check_in_at', header: 'Next Check-in', render: (r: any) => <span className="text-xs">{fmtDate(r.next_check_in_at)}</span> },
  ];

  const milestoneCols: Column<any>[] = [
    { key: 'milestone_title', header: 'Milestone', render: (r: any) => <span className="font-medium">{r.milestone_title}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="text-xs">{r.status}</span> },
    { key: 'target_at', header: 'Target', render: (r: any) => <span className="text-xs">{fmtDate(r.target_at)}</span> },
    { key: 'completed_at', header: 'Completed', render: (r: any) => <span className="text-xs">{fmtDate(r.completed_at)}</span> },
    { key: 'manager_signoff_at', header: 'Sign-off', render: (r: any) => <span className="text-xs">{fmtDate(r.manager_signoff_at)}</span> },
  ];

  const topReadyCols: Column<any>[] = [
    { key: 'goal_title', header: 'Goal', render: (r: any) => <span className="font-medium">{r.goal_title}</span> },
    { key: 'career_track', header: 'Track', render: (r: any) => <span className="text-xs">{r.career_track}</span> },
    { key: 'promotion_readiness_pct', header: 'Readiness', render: (r: any) => <span className="font-mono font-bold">{r.promotion_readiness_pct}%</span> },
    { key: 'next_check_in_at', header: 'Next Check-in', render: (r: any) => <span className="text-xs">{fmtDate(r.next_check_in_at)}</span> },
  ];

  const overdueCols: Column<any>[] = [
    { key: 'milestone_title', header: 'Milestone', render: (r: any) => <span className="font-medium">{r.milestone_title}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="text-xs">{r.status}</span> },
    { key: 'target_at', header: 'Target', render: (r: any) => <span className="text-xs">{fmtDate(r.target_at)}</span> },
    { key: 'days_overdue', header: 'Days Overdue', render: (r: any) => <span className="font-mono text-red-600">{r.days_overdue}d</span> },
  ];

  const managerCols: Column<any>[] = [
    { key: 'manager_email', header: 'Manager', render: (r: any) => <span className="text-xs">{r.manager_email}</span> },
    { key: 'active_goals', header: 'Active Goals', render: (r: any) => <span className="font-mono">{r.active_goals}</span> },
    { key: 'avg_readiness_pct', header: 'Avg Readiness', render: (r: any) => <span className="font-mono">{r.avg_readiness_pct ?? 0}%</span> },
    { key: 'upcoming_checkins', header: 'Upcoming Check-ins (14d)', render: (r: any) => <span className="font-mono">{r.upcoming_checkins}</span> },
  ];

  const trackCols: Column<any>[] = [
    { key: 'career_track', header: 'Track', render: (r: any) => <span className="text-xs uppercase">{r.career_track}</span> },
    { key: 'goal_count', header: 'Goals', render: (r: any) => <span className="font-mono">{r.goal_count}</span> },
    { key: 'active_count', header: 'Active', render: (r: any) => <span className="font-mono">{r.active_count}</span> },
    { key: 'avg_readiness_pct', header: 'Avg Readiness', render: (r: any) => <span className="font-mono">{r.avg_readiness_pct ?? 0}%</span> },
  ];

  return (
    <div className="p-6 space-y-8 max-w-7xl mx-auto">
      <div>
        <h1 className="text-2xl font-bold">Engineer Personal Development Plan</h1>
        <p className="text-sm text-gray-600 mt-1">Per-engineer career goal × 90-day plan × milestones × manager check-in × promotion-readiness.</p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
        <div className="border rounded-lg p-4">
          <div className="text-xs text-gray-500">Total Milestones</div>
          <div className="text-2xl font-bold mt-1">{c.total_milestones}</div>
        </div>
        <div className="border rounded-lg p-4">
          <div className="text-xs text-gray-500">Done</div>
          <div className="text-2xl font-bold mt-1 text-green-600">{c.done_count}</div>
        </div>
        <div className="border rounded-lg p-4">
          <div className="text-xs text-gray-500">In Progress</div>
          <div className="text-2xl font-bold mt-1 text-blue-600">{c.in_progress_count}</div>
        </div>
        <div className="border rounded-lg p-4">
          <div className="text-xs text-gray-500">Blocked</div>
          <div className="text-2xl font-bold mt-1 text-red-600">{c.blocked_count}</div>
        </div>
        <div className="border rounded-lg p-4">
          <div className="text-xs text-gray-500">Completion %</div>
          <div className="text-2xl font-bold mt-1">{c.completion_pct}%</div>
        </div>
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Promotion-Ready (>=70%)</h2>
        <DataTable
          rows={topReady}
          columns={topReadyCols}
          emptyMessage="No engineers above 70% readiness yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Overdue Milestones</h2>
        <DataTable
          rows={overdue}
          columns={overdueCols}
          emptyMessage="No overdue milestones."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All PDP Goals</h2>
        <DataTable
          rows={goals}
          columns={goalCols}
          emptyMessage="No PDP goals yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Milestones</h2>
        <DataTable
          rows={milestones}
          columns={milestoneCols}
          emptyMessage="No milestones yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Manager Load</h2>
        <DataTable
          rows={managerLoad}
          columns={managerCols}
          emptyMessage="No managers assigned."
          rowKey={(r: any, i: number) => String(r.manager_email ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Career Track Distribution</h2>
        <DataTable
          rows={trackDist}
          columns={trackCols}
          emptyMessage="No career tracks tracked."
          rowKey={(r: any, i: number) => String(r.career_track ?? i)}
        />
      </section>
    </div>
  );
}
