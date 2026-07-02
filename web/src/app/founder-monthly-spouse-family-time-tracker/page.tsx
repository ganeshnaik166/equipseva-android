import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderMonthlySpouseFamilyTimeTrackerPage() {
  const supabase = await getSupabaseServerClient();

  const [familyRes, actionsRes, drainRes, gradeRes, statusRes, trendRes, pulseRes] = await Promise.all([
    supabase.rpc('list_family_time_r2653'),
    supabase.rpc('list_recovery_actions_r2653'),
    supabase.rpc('top_drain_focus_r2653'),
    supabase.rpc('grade_distribution_r2653'),
    supabase.rpc('status_funnel_r2653'),
    supabase.rpc('monthly_family_trend_r2653'),
    supabase.rpc('founder_pulse_summary_r2653'),
  ]);

  const family = (familyRes.data as any[]) ?? [];
  const actions = (actionsRes.data as any[]) ?? [];
  const drain = (drainRes.data as any[]) ?? [];
  const grade = (gradeRes.data as any[]) ?? [];
  const statusFunnel = (statusRes.data as any[]) ?? [];
  const trend = (trendRes.data as any[]) ?? [];
  const pulse = ((pulseRes.data as any[]) ?? [])[0] ?? {};

  const familyCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'family_hours', header: 'Family Hours', render: (r: any) => Number(r.family_hours ?? 0).toFixed(1) },
    { key: 'date_nights', header: 'Date Nights', render: (r: any) => r.date_nights },
    { key: 'family_trips', header: 'Trips', render: (r: any) => r.family_trips },
    { key: 'family_grade', header: 'Grade', render: (r: any) => r.family_grade },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'top_drain_md', header: 'Top Drain', render: (r: any) => r.top_drain_md ?? '' },
    { key: 'top_invest_md', header: 'Top Invest', render: (r: any) => r.top_invest_md ?? '' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const actionsCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'action_at', header: 'When', render: (r: any) => new Date(r.action_at).toLocaleString() },
    { key: 'action_kind', header: 'Action', render: (r: any) => r.action_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const drainCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'family_hours', header: 'Hours', render: (r: any) => Number(r.family_hours ?? 0).toFixed(1) },
    { key: 'family_grade', header: 'Grade', render: (r: any) => r.family_grade },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'top_drain_md', header: 'Top Drain', render: (r: any) => r.top_drain_md ?? '' },
  ];

  const gradeCols: Column<any>[] = [
    { key: 'family_grade', header: 'Grade', render: (r: any) => r.family_grade },
    { key: 'n', header: 'Count', render: (r: any) => r.n },
  ];

  const statusCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'n', header: 'Count', render: (r: any) => r.n },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'family_hours', header: 'Hours', render: (r: any) => Number(r.family_hours ?? 0).toFixed(1) },
    { key: 'date_nights', header: 'Date Nights', render: (r: any) => r.date_nights },
    { key: 'family_trips', header: 'Trips', render: (r: any) => r.family_trips },
    { key: 'family_grade', header: 'Grade', render: (r: any) => r.family_grade },
  ];

  return (
    <main className="p-6 space-y-8 max-w-7xl mx-auto">
      <header>
        <h1 className="text-2xl font-bold">Founder Monthly Spouse & Family Time Tracker</h1>
        <p className="text-sm text-gray-600 mt-1">Track family hours, date nights, trips, grade & recovery actions month over month.</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div className="rounded border p-3"><div className="text-xs text-gray-500">Total Months</div><div className="text-xl font-semibold">{pulse.total_months ?? 0}</div></div>
        <div className="rounded border p-3"><div className="text-xs text-gray-500">Strained</div><div className="text-xl font-semibold">{pulse.strained_months ?? 0}</div></div>
        <div className="rounded border p-3"><div className="text-xs text-gray-500">Healthy</div><div className="text-xl font-semibold">{pulse.healthy_months ?? 0}</div></div>
        <div className="rounded border p-3"><div className="text-xs text-gray-500">Avg Hours</div><div className="text-xl font-semibold">{Number(pulse.avg_family_hours ?? 0).toFixed(1)}</div></div>
        <div className="rounded border p-3"><div className="text-xs text-gray-500">Total Date Nights</div><div className="text-xl font-semibold">{pulse.total_date_nights ?? 0}</div></div>
        <div className="rounded border p-3"><div className="text-xs text-gray-500">Total Trips</div><div className="text-xl font-semibold">{pulse.total_trips ?? 0}</div></div>
        <div className="rounded border p-3"><div className="text-xs text-gray-500">Open Actions</div><div className="text-xl font-semibold">{pulse.open_actions ?? 0}</div></div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Family Time</h2>
        <DataTable rows={family} columns={familyCols} emptyMessage="No months tracked yet" rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recovery Actions</h2>
        <DataTable rows={actions} columns={actionsCols} emptyMessage="No recovery actions" rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Drain Focus (D/F & Strained)</h2>
        <DataTable rows={drain} columns={drainCols} emptyMessage="No drain months" rowKey={(r: any, i: number) => String(r.month_label ?? i)} />
      </section>

      <section className="grid md:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-2">Grade Distribution</h2>
          <DataTable rows={grade} columns={gradeCols} emptyMessage="No grades" rowKey={(r: any, i: number) => String(r.family_grade ?? i)} />
        </div>
        <div>
          <h2 className="text-lg font-semibold mb-2">Status Funnel</h2>
          <DataTable rows={statusFunnel} columns={statusCols} emptyMessage="No statuses" rowKey={(r: any, i: number) => String(r.status ?? i)} />
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Family Trend</h2>
        <DataTable rows={trend} columns={trendCols} emptyMessage="No trend data" rowKey={(r: any, i: number) => String(r.month_label ?? i)} />
      </section>
    </main>
  );
}
