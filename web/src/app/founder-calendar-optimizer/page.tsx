import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderCalendarOptimizerPage() {
  const sb = await getSupabaseServerClient();

  const [weeksRes, targetsRes, trendRes, violationsRes, recentRes] = await Promise.all([
    sb.rpc('r1894_list_weeks'),
    sb.rpc('r1894_list_targets'),
    sb.rpc('r1894_optimization_trend'),
    sb.rpc('r1894_top_violations'),
    sb.rpc('r1894_recent_weeks'),
  ]);

  const weeks: any[] = Array.isArray(weeksRes.data) ? weeksRes.data : [];
  const targets: any[] = Array.isArray(targetsRes.data) ? targetsRes.data : [];
  const trend: any[] = Array.isArray(trendRes.data) ? trendRes.data : [];
  const violations: any[] = Array.isArray(violationsRes.data) ? violationsRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const avgScore = trend.length > 0
    ? Math.round(trend.reduce((s, r) => s + (Number(r.optimization_score) || 0), 0) / trend.length)
    : 0;
  const avgDeepWork = trend.length > 0
    ? (trend.reduce((s, r) => s + (Number(r.deep_work_pct) || 0), 0) / trend.length).toFixed(1)
    : '0.0';
  const totalViolations = violations.length;

  const weeksCols: Column<any>[] = [
    { key: 'week_start', header: 'Week Start', render: (r: any) => String(r.week_start ?? '') },
    { key: 'optimization_score', header: 'Score', render: (r: any) => `${r.optimization_score ?? 0}/100` },
    { key: 'total_meeting_minutes', header: 'Meeting Min', render: (r: any) => String(r.total_meeting_minutes ?? 0) },
    { key: 'deep_work_minutes', header: 'Deep Work Min', render: (r: any) => String(r.deep_work_minutes ?? 0) },
    { key: 'no_fly_zone_minutes', header: 'No-Fly Min', render: (r: any) => String(r.no_fly_zone_minutes ?? 0) },
    { key: 'batched_meeting_minutes', header: 'Batched Min', render: (r: any) => String(r.batched_meeting_minutes ?? 0) },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => r.recorded_at ? new Date(r.recorded_at).toLocaleString() : '' },
  ];

  const targetsCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => String(r.week_start ?? '') },
    { key: 'target_type', header: 'Target Type', render: (r: any) => String(r.target_type ?? '') },
    { key: 'target_value', header: 'Target', render: (r: any) => String(r.target_value ?? 0) },
    { key: 'actual_value', header: 'Actual', render: (r: any) => String(r.actual_value ?? 0) },
    { key: 'gap', header: 'Gap (actual minus target)', render: (r: any) => String(r.gap ?? 0) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => String(r.week_start ?? '') },
    { key: 'optimization_score', header: 'Score', render: (r: any) => String(r.optimization_score ?? 0) },
    { key: 'deep_work_pct', header: 'Deep Work %', render: (r: any) => `${r.deep_work_pct ?? 0}%` },
    { key: 'no_fly_pct', header: 'No-Fly %', render: (r: any) => `${r.no_fly_pct ?? 0}%` },
    { key: 'batched_pct', header: 'Batched %', render: (r: any) => `${r.batched_pct ?? 0}%` },
  ];

  const violationsCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => String(r.week_start ?? '') },
    { key: 'target_type', header: 'Target Type', render: (r: any) => String(r.target_type ?? '') },
    { key: 'target_value', header: 'Target', render: (r: any) => String(r.target_value ?? 0) },
    { key: 'actual_value', header: 'Actual', render: (r: any) => String(r.actual_value ?? 0) },
    { key: 'gap', header: 'Shortfall', render: (r: any) => String(r.gap ?? 0) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => String(r.week_start ?? '') },
    { key: 'optimization_score', header: 'Score', render: (r: any) => `${r.optimization_score ?? 0}/100` },
    { key: 'total_meeting_minutes', header: 'Meeting Min', render: (r: any) => String(r.total_meeting_minutes ?? 0) },
    { key: 'deep_work_minutes', header: 'Deep Work Min', render: (r: any) => String(r.deep_work_minutes ?? 0) },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => r.recorded_at ? new Date(r.recorded_at).toLocaleString() : '' },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Founder Calendar Optimizer</h1>
        <p className="text-sm text-gray-600 mt-1">
          Density optimization: no-fly zones, batched meetings &amp; deep work blocks. Score reflects
          adherence to weekly targets (higher score &gt;= better calendar discipline).
        </p>
      </header>

      <section className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Avg Optimization Score (last 26w)</div>
          <div className="text-2xl font-bold mt-1">{avgScore}/100</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Avg Deep Work %</div>
          <div className="text-2xl font-bold mt-1">{avgDeepWork}%</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Active Violations (actual &lt; target)</div>
          <div className="text-2xl font-bold mt-1">{totalViolations}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Weeks</h2>
        <p className="text-xs text-gray-500 mb-2">Last 12 weeks recorded.</p>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.week_start ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Optimization Trend</h2>
        <p className="text-xs text-gray-500 mb-2">Week-by-week density mix. Targets typically: deep work &gt;= 30%, no-fly &gt;= 20%, batched &gt;= 50% of meetings.</p>
        <DataTable rows={trend} columns={trendCols} rowKey={(r: any, i: number) => String(r.week_start ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Weeks</h2>
        <DataTable rows={weeks} columns={weeksCols} rowKey={(r: any, i: number) => String(r.week_start ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Targets</h2>
        <p className="text-xs text-gray-500 mb-2">Per-week targets (deep work %, batched %, no-fly %, total meetings count).</p>
        <DataTable rows={targets} columns={targetsCols} rowKey={(r: any, i: number) => `${r.week_start}-${r.target_type}-${i}`} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Violations</h2>
        <p className="text-xs text-gray-500 mb-2">Weeks where actual &lt; target. Sorted by largest shortfall.</p>
        <DataTable rows={violations} columns={violationsCols} rowKey={(r: any, i: number) => `${r.week_start}-${r.target_type}-${i}`} />
      </section>
    </main>
  );
}
