import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerCareerPathTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [pathsRes, milestonesRes, jeopardyRes, achieversRes] = await Promise.all([
    sb.rpc('list_paths_r1692'),
    sb.rpc('list_milestones_r1692', { p_path_id: null }),
    sb.rpc('paths_in_jeopardy_r1692'),
    sb.rpc('achievers_recent_r1692'),
  ]);

  const paths: any[] = (pathsRes.data as any[]) || [];
  const milestones: any[] = (milestonesRes.data as any[]) || [];
  const jeopardy: any[] = (jeopardyRes.data as any[]) || [];
  const achievers: any[] = (achieversRes.data as any[]) || [];

  const totalPaths = paths.length;
  const activePaths = paths.filter((p: any) => p.status === 'active').length;
  const achievedCount = paths.filter((p: any) => p.status === 'achieved').length;
  const avgProgress = paths.length > 0
    ? Math.round(paths.reduce((s: number, p: any) => s + Number(p.progress_pct || 0), 0) / paths.length)
    : 0;
  const pendingMilestones = milestones.filter((m: any) => m.status === 'pending').length;
  const overdueMilestones = milestones.filter((m: any) => m.status === 'pending' && m.due_date && new Date(m.due_date) < new Date()).length;
  const doneMilestones = milestones.filter((m: any) => m.status === 'done').length;

  const pathCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => <span className="font-medium">{r.engineer_email ?? String(r.engineer_user_id).slice(0, 8)}</span> },
    { key: 'target_role', header: 'Target Role', render: (r: any) => <span className="text-blue-700 font-semibold">{r.target_role}</span> },
    { key: 'target_date', header: 'Target Date', render: (r: any) => r.target_date ? new Date(r.target_date).toLocaleDateString() : '—' },
    {
      key: 'days_to_target',
      header: 'Days Left',
      render: (r: any) => {
        if (r.days_to_target == null) return '—';
        const d = Number(r.days_to_target);
        const cls = d < 0 ? 'text-red-700 font-bold' : d < 30 ? 'text-orange-700 font-semibold' : 'text-gray-700';
        return <span className={cls}>{d}d</span>;
      },
    },
    {
      key: 'status',
      header: 'Status',
      render: (r: any) => {
        const colorMap: Record<string, string> = {
          active: 'bg-blue-100 text-blue-800',
          paused: 'bg-gray-100 text-gray-800',
          achieved: 'bg-green-100 text-green-800',
          dropped: 'bg-red-100 text-red-800',
        };
        return (
          <span className={`px-2 py-0.5 rounded text-xs font-medium ${colorMap[r.status] || 'bg-gray-100'}`}>
            {r.status}
          </span>
        );
      },
    },
    {
      key: 'progress_pct',
      header: 'Progress',
      render: (r: any) => {
        const pct = Number(r.progress_pct || 0);
        const cls = pct >= 75 ? 'text-green-700 font-bold' : pct >= 40 ? 'text-blue-700' : 'text-gray-700';
        return (
          <div className="flex items-center gap-2">
            <div className="w-20 h-2 bg-gray-200 rounded overflow-hidden">
              <div className="h-full bg-blue-500" style={{ width: `${Math.min(100, pct)}%` }} />
            </div>
            <span className={cls}>{pct}%</span>
          </div>
        );
      },
    },
    { key: 'milestones_total', header: 'Milestones', render: (r: any) => `${r.milestones_done}/${r.milestones_total}` },
    { key: 'milestones_missed', header: 'Missed', render: (r: any) => r.milestones_missed > 0 ? <span className="text-red-700 font-semibold">{r.milestones_missed}</span> : r.milestones_missed },
    { key: 'created_at', header: 'Created', render: (r: any) => new Date(r.created_at).toLocaleDateString() },
  ];

  const milestoneCols: Column<any>[] = [
    { key: 'target_role', header: 'Path', render: (r: any) => <span className="text-blue-700 text-xs">{r.target_role}</span> },
    { key: 'milestone_text', header: 'Milestone', render: (r: any) => <span className="font-medium">{r.milestone_text}</span> },
    { key: 'due_date', header: 'Due', render: (r: any) => r.due_date ? new Date(r.due_date).toLocaleDateString() : '—' },
    {
      key: 'days_to_due',
      header: 'Days',
      render: (r: any) => {
        if (r.days_to_due == null) return '—';
        const d = Number(r.days_to_due);
        const cls = d < 0 ? 'text-red-700 font-bold' : d < 7 ? 'text-orange-700 font-semibold' : 'text-gray-700';
        return <span className={cls}>{d}d</span>;
      },
    },
    {
      key: 'status',
      header: 'Status',
      render: (r: any) => {
        const colorMap: Record<string, string> = {
          pending: 'bg-yellow-100 text-yellow-800',
          done: 'bg-green-100 text-green-800',
          missed: 'bg-red-100 text-red-800',
        };
        return (
          <span className={`px-2 py-0.5 rounded text-xs font-medium ${colorMap[r.status] || 'bg-gray-100'}`}>
            {r.status}
          </span>
        );
      },
    },
    { key: 'completed_at', header: 'Completed', render: (r: any) => r.completed_at ? new Date(r.completed_at).toLocaleDateString() : '—' },
  ];

  const jeopardyCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => <span className="font-medium">{r.engineer_email ?? String(r.engineer_user_id).slice(0, 8)}</span> },
    { key: 'target_role', header: 'Target Role', render: (r: any) => r.target_role },
    { key: 'target_date', header: 'Target Date', render: (r: any) => r.target_date ? new Date(r.target_date).toLocaleDateString() : '—' },
    {
      key: 'days_to_target',
      header: 'Days Left',
      render: (r: any) => {
        if (r.days_to_target == null) return '—';
        const d = Number(r.days_to_target);
        return <span className={d < 0 ? 'text-red-700 font-bold' : 'text-orange-700 font-semibold'}>{d}d</span>;
      },
    },
    { key: 'milestones_overdue', header: 'Overdue', render: (r: any) => <span className="text-red-700 font-bold">{r.milestones_overdue}</span> },
    { key: 'progress_pct', header: 'Progress', render: (r: any) => `${r.progress_pct}%` },
    { key: 'jeopardy_reason', header: 'Reason', render: (r: any) => <span className="text-xs text-red-800">{r.jeopardy_reason}</span> },
  ];

  const achieverCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => <span className="font-medium">{r.engineer_email ?? String(r.engineer_user_id).slice(0, 8)}</span> },
    { key: 'target_role', header: 'Achieved Role', render: (r: any) => <span className="text-green-700 font-semibold">{r.target_role}</span> },
    { key: 'achieved_at', header: 'Achieved On', render: (r: any) => new Date(r.achieved_at).toLocaleDateString() },
    { key: 'target_date', header: 'Original Target', render: (r: any) => r.target_date ? new Date(r.target_date).toLocaleDateString() : '—' },
    { key: 'milestones_done', header: 'Milestones', render: (r: any) => `${r.milestones_done}/${r.milestones_total}` },
  ];

  return (
    <main className="min-h-screen bg-gray-50 p-6">
      <div className="max-w-7xl mx-auto space-y-6">
        <header className="border-b pb-4">
          <h1 className="text-3xl font-bold text-gray-900">Engineer Career Path Tracker</h1>
          <p className="text-sm text-gray-600 mt-1">
            Per-engineer career goals, milestone plans, and jeopardy detection. Progress &gt;=75% flagged green.
          </p>
        </header>

        {/* KPI section */}
        <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="bg-white rounded-lg shadow p-4">
            <div className="text-xs text-gray-500 uppercase">Total Paths</div>
            <div className="text-2xl font-bold mt-1">{totalPaths}</div>
          </div>
          <div className="bg-white rounded-lg shadow p-4">
            <div className="text-xs text-gray-500 uppercase">Active</div>
            <div className="text-2xl font-bold mt-1 text-blue-700">{activePaths}</div>
          </div>
          <div className="bg-white rounded-lg shadow p-4">
            <div className="text-xs text-gray-500 uppercase">Achieved</div>
            <div className="text-2xl font-bold mt-1 text-green-700">{achievedCount}</div>
          </div>
          <div className="bg-white rounded-lg shadow p-4">
            <div className="text-xs text-gray-500 uppercase">Avg Progress</div>
            <div className="text-2xl font-bold mt-1">{avgProgress}%</div>
          </div>
          <div className="bg-white rounded-lg shadow p-4">
            <div className="text-xs text-gray-500 uppercase">Milestones Done</div>
            <div className="text-2xl font-bold mt-1 text-green-700">{doneMilestones}</div>
          </div>
          <div className="bg-white rounded-lg shadow p-4">
            <div className="text-xs text-gray-500 uppercase">Pending</div>
            <div className="text-2xl font-bold mt-1">{pendingMilestones}</div>
          </div>
          <div className="bg-white rounded-lg shadow p-4">
            <div className="text-xs text-gray-500 uppercase">Overdue</div>
            <div className="text-2xl font-bold mt-1 text-red-700">{overdueMilestones}</div>
          </div>
          <div className="bg-white rounded-lg shadow p-4">
            <div className="text-xs text-gray-500 uppercase">In Jeopardy</div>
            <div className="text-2xl font-bold mt-1 text-orange-700">{jeopardy.length}</div>
          </div>
        </section>

        {/* Primary table: all paths */}
        <section className="bg-white rounded-lg shadow p-4">
          <h2 className="text-xl font-semibold mb-3">All Career Paths</h2>
          <DataTable rows={paths} columns={pathCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
        </section>

        {/* Action queue: jeopardy */}
        <section className="bg-white rounded-lg shadow p-4 border-l-4 border-red-500">
          <h2 className="text-xl font-semibold mb-3">Action Queue — Paths In Jeopardy</h2>
          <p className="text-sm text-gray-600 mb-3">
            Active paths with overdue milestones, target date passed, or target within 30 days. Intervene with 1:1 + replan.
          </p>
          <DataTable rows={jeopardy} columns={jeopardyCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
        </section>

        {/* Milestones */}
        <section className="bg-white rounded-lg shadow p-4">
          <h2 className="text-xl font-semibold mb-3">All Milestones</h2>
          <DataTable rows={milestones.slice(0, 100)} columns={milestoneCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
        </section>

        {/* Achievers */}
        <section className="bg-white rounded-lg shadow p-4 border-l-4 border-green-500">
          <h2 className="text-xl font-semibold mb-3">Recent Achievers (last 180 days)</h2>
          <DataTable rows={achievers} columns={achieverCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
        </section>
      </div>
    </main>
  );
}
