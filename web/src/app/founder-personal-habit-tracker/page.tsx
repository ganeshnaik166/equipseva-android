import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderPersonalHabitTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [overviewRes, habitsRes, streaksRes, complianceRes, logsRes] = await Promise.all([
    sb.rpc('habit_overview_r1810'),
    sb.rpc('list_habits_r1810'),
    sb.rpc('streak_calc_r1810'),
    sb.rpc('weekly_compliance_r1810', { p_weeks: 4 }),
    sb.rpc('list_logs_r1810', { p_days: 30 }),
  ]);

  const overview = (overviewRes.data ?? [])[0] ?? null;
  const habits: any[] = habitsRes.data ?? [];
  const streaks: any[] = streaksRes.data ?? [];
  const compliance: any[] = complianceRes.data ?? [];
  const logs: any[] = logsRes.data ?? [];

  const habitCols: Column<any>[] = [
    { key: 'habit_name', header: 'Habit', render: (r: any) => <span className="font-medium">{r.habit_name}</span> },
    { key: 'habit_category', header: 'Category', render: (r: any) => <span className="capitalize">{r.habit_category}</span> },
    { key: 'target_frequency_per_week', header: 'Target / wk', render: (r: any) => <span>{r.target_frequency_per_week}x</span> },
    { key: 'importance', header: 'Importance', render: (r: any) => (
      <span className={
        r.importance === 'critical' ? 'text-red-600 font-semibold' :
        r.importance === 'important' ? 'text-amber-600' : 'text-gray-500'
      }>{r.importance}</span>
    ) },
    { key: 'active', header: 'Active', render: (r: any) => r.active ? 'Yes' : 'No' },
  ];

  const streakCols: Column<any>[] = [
    { key: 'habit_name', header: 'Habit', render: (r: any) => <span className="font-medium">{r.habit_name}</span> },
    { key: 'habit_category', header: 'Category', render: (r: any) => <span className="capitalize">{r.habit_category}</span> },
    { key: 'current_streak', header: 'Current', render: (r: any) => (
      <span className={r.current_streak >= 7 ? 'text-green-700 font-semibold' : r.current_streak === 0 ? 'text-red-600' : ''}>
        {r.current_streak} days
      </span>
    ) },
    { key: 'longest_streak', header: 'Longest', render: (r: any) => <span>{r.longest_streak} days</span> },
    { key: 'last_completed', header: 'Last done', render: (r: any) => r.last_completed ? new Date(r.last_completed).toLocaleDateString() : '—' },
  ];

  const complianceCols: Column<any>[] = [
    { key: 'week_start', header: 'Week of', render: (r: any) => new Date(r.week_start).toLocaleDateString() },
    { key: 'habit_name', header: 'Habit', render: (r: any) => <span className="font-medium">{r.habit_name}</span> },
    { key: 'completed_count', header: 'Done', render: (r: any) => <span>{r.completed_count}</span> },
    { key: 'target_frequency_per_week', header: 'Target', render: (r: any) => <span>{r.target_frequency_per_week}</span> },
    { key: 'compliance_pct', header: 'Compliance', render: (r: any) => (
      <span className={
        Number(r.compliance_pct) >= 100 ? 'text-green-700 font-semibold' :
        Number(r.compliance_pct) >= 70 ? 'text-amber-600' : 'text-red-600'
      }>{Number(r.compliance_pct ?? 0).toFixed(1)}%</span>
    ) },
  ];

  const logCols: Column<any>[] = [
    { key: 'log_date', header: 'Date', render: (r: any) => new Date(r.log_date).toLocaleDateString() },
    { key: 'habit_name', header: 'Habit', render: (r: any) => <span className="font-medium">{r.habit_name}</span> },
    { key: 'habit_category', header: 'Category', render: (r: any) => <span className="capitalize">{r.habit_category}</span> },
    { key: 'completed', header: 'Status', render: (r: any) => (
      <span className={r.completed ? 'text-green-700' : 'text-red-600'}>{r.completed ? 'Done' : 'Missed'}</span>
    ) },
    { key: 'note', header: 'Note', render: (r: any) => <span className="text-gray-600 text-sm">{r.note ?? '—'}</span> },
  ];

  return (
    <div className="p-6 space-y-8 max-w-7xl mx-auto">
      <header>
        <h1 className="text-2xl font-bold">Founder Personal Habit Tracker</h1>
        <p className="text-gray-600 mt-1">Daily habits, streaks, and weekly compliance for health, mind, work, relationships & learning.</p>
      </header>

      {overview && (
        <section>
          <h2 className="text-lg font-semibold mb-3">Overview</h2>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div className="rounded border p-4">
              <div className="text-xs text-gray-500 uppercase">Active habits</div>
              <div className="text-2xl font-bold mt-1">{overview.active_habits ?? 0}</div>
              <div className="text-xs text-gray-500 mt-1">of {overview.total_habits ?? 0} total</div>
            </div>
            <div className="rounded border p-4">
              <div className="text-xs text-gray-500 uppercase">Critical habits</div>
              <div className="text-2xl font-bold mt-1 text-red-600">{overview.critical_habits ?? 0}</div>
              <div className="text-xs text-gray-500 mt-1">must-do daily</div>
            </div>
            <div className="rounded border p-4">
              <div className="text-xs text-gray-500 uppercase">Today completion</div>
              <div className="text-2xl font-bold mt-1">
                {Number(overview.completion_rate_today ?? 0).toFixed(1)}%
              </div>
              <div className="text-xs text-gray-500 mt-1">{overview.completed_today ?? 0} / {overview.active_habits ?? 0} done</div>
            </div>
            <div className="rounded border p-4">
              <div className="text-xs text-gray-500 uppercase">Longest current streak</div>
              <div className="text-2xl font-bold mt-1 text-green-700">{overview.longest_current_streak ?? 0}</div>
              <div className="text-xs text-gray-500 mt-1">{overview.habits_at_risk ?? 0} at risk (streak = 0)</div>
            </div>
          </div>
        </section>
      )}

      <section>
        <h2 className="text-lg font-semibold mb-3">Habit Definitions</h2>
        <DataTable rows={habits} columns={habitCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Streaks (active habits)</h2>
        <DataTable rows={streaks} columns={streakCols} rowKey={(r: any, i: number) => String(r.habit_id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Weekly Compliance (last 4 weeks)</h2>
        <DataTable rows={compliance} columns={complianceCols} rowKey={(r: any, i: number) => String((r.habit_id ?? '') + '-' + (r.week_start ?? i))} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Recent Logs (last 30 days)</h2>
        <DataTable rows={logs} columns={logCols} rowKey={(r: any, i: number) => String(r.log_id ?? i)} />
      </section>
    </div>
  );
}
