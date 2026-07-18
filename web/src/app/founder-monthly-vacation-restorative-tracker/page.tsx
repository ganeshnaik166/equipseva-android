import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderMonthlyVacationRestorativeTrackerPage() {
  const supabase = await getSupabaseServerClient();

  const [
    restorationRes,
    intentionsRes,
    trendRes,
    completionRes,
    restorersRes,
    drainsRes,
    pulseRes,
  ] = await Promise.all([
    supabase.rpc('list_restoration_r2477'),
    supabase.rpc('list_intentions_r2477'),
    supabase.rpc('stress_vs_creative_trend_r2477'),
    supabase.rpc('intention_completion_summary_r2477'),
    supabase.rpc('top_restorers_r2477'),
    supabase.rpc('top_drains_r2477'),
    supabase.rpc('monthly_pulse_summary_r2477'),
  ]);

  const restoration: any[] = restorationRes.data ?? [];
  const intentions: any[] = intentionsRes.data ?? [];
  const trend: any[] = trendRes.data ?? [];
  const completion: any[] = completionRes.data ?? [];
  const restorers: any[] = restorersRes.data ?? [];
  const drains: any[] = drainsRes.data ?? [];
  const pulse: any = (pulseRes.data ?? [])[0] ?? null;

  const restorationColumns: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => String(r.month_start) },
    { key: 'days_off_taken', header: 'Days Off', render: (r: any) => String(r.days_off_taken) },
    { key: 'creative_time_hours', header: 'Creative hrs', render: (r: any) => String(r.creative_time_hours) },
    { key: 'stress_score', header: 'Stress', render: (r: any) => String(r.stress_score) + '/10' },
    { key: 'energy_score', header: 'Energy', render: (r: any) => String(r.energy_score) + '/10' },
    { key: 'sleep_avg_hours', header: 'Sleep hrs', render: (r: any) => String(r.sleep_avg_hours) },
    { key: 'exercise_hours', header: 'Exercise hrs', render: (r: any) => String(r.exercise_hours) },
    { key: 'mood', header: 'Mood', render: (r: any) => r.mood ?? '' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const intentionColumns: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => String(r.month_start) },
    { key: 'intention_kind', header: 'Intention', render: (r: any) => String(r.intention_kind) },
    { key: 'planned', header: 'Planned', render: (r: any) => (r.planned ? 'yes' : 'no') },
    { key: 'actual_hours', header: 'Actual hrs', render: (r: any) => String(r.actual_hours) },
    { key: 'satisfaction', header: 'Satisfaction', render: (r: any) => String(r.satisfaction) + '/10' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status) },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const trendColumns: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => String(r.month_start) },
    { key: 'stress_score', header: 'Stress', render: (r: any) => String(r.stress_score) },
    { key: 'energy_score', header: 'Energy', render: (r: any) => String(r.energy_score) },
    { key: 'creative_time_hours', header: 'Creative hrs', render: (r: any) => String(r.creative_time_hours) },
    { key: 'days_off_taken', header: 'Days off', render: (r: any) => String(r.days_off_taken) },
    { key: 'sleep_avg_hours', header: 'Sleep', render: (r: any) => String(r.sleep_avg_hours) },
    { key: 'exercise_hours', header: 'Exercise', render: (r: any) => String(r.exercise_hours) },
  ];

  const completionColumns: Column<any>[] = [
    { key: 'intention_kind', header: 'Intention', render: (r: any) => String(r.intention_kind) },
    { key: 'total', header: 'Total', render: (r: any) => String(r.total) },
    { key: 'done_count', header: 'Done', render: (r: any) => String(r.done_count) },
    { key: 'missed_count', header: 'Missed', render: (r: any) => String(r.missed_count) },
    { key: 'dropped_count', header: 'Dropped', render: (r: any) => String(r.dropped_count) },
    { key: 'planned_count', header: 'Planned', render: (r: any) => String(r.planned_count) },
    { key: 'avg_satisfaction', header: 'Avg satisfaction', render: (r: any) => String(r.avg_satisfaction) },
    { key: 'total_actual_hours', header: 'Total hrs', render: (r: any) => String(r.total_actual_hours) },
  ];

  const restorerColumns: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => String(r.month_start) },
    { key: 'top_restorers_md', header: 'Top restorers', render: (r: any) => r.top_restorers_md ?? '' },
    { key: 'energy_score', header: 'Energy', render: (r: any) => String(r.energy_score) },
    { key: 'creative_time_hours', header: 'Creative hrs', render: (r: any) => String(r.creative_time_hours) },
    { key: 'mood', header: 'Mood', render: (r: any) => r.mood ?? '' },
  ];

  const drainColumns: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => String(r.month_start) },
    { key: 'top_drains_md', header: 'Top drains', render: (r: any) => r.top_drains_md ?? '' },
    { key: 'stress_score', header: 'Stress', render: (r: any) => String(r.stress_score) },
    { key: 'days_off_taken', header: 'Days off', render: (r: any) => String(r.days_off_taken) },
    { key: 'mood', header: 'Mood', render: (r: any) => r.mood ?? '' },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: '1200px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '8px' }}>
        Founder Monthly Vacation & Restorative Tracker
      </h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Days off & restorative practices &gt; creative-time &gt; stress score &gt; month-over-month trend.
      </p>

      {pulse && (
        <section style={{ marginBottom: '32px', padding: '16px', background: '#f7f7f9', borderRadius: '8px' }}>
          <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Pulse Summary</h2>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: '12px' }}>
            <div><strong>Months tracked:</strong> {String(pulse.months_tracked)}</div>
            <div><strong>Avg days off:</strong> {String(pulse.avg_days_off)}</div>
            <div><strong>Avg stress:</strong> {String(pulse.avg_stress)}/10</div>
            <div><strong>Avg energy:</strong> {String(pulse.avg_energy)}/10</div>
            <div><strong>Avg sleep:</strong> {String(pulse.avg_sleep)} hrs</div>
            <div><strong>Avg creative hrs:</strong> {String(pulse.avg_creative_hours)}</div>
            <div><strong>Avg exercise hrs:</strong> {String(pulse.avg_exercise_hours)}</div>
            <div><strong>Best month:</strong> {String(pulse.best_month ?? '')}</div>
            <div><strong>Worst month:</strong> {String(pulse.worst_month ?? '')}</div>
            <div><strong>Stress trend:</strong> {String(pulse.trending)}</div>
          </div>
        </section>
      )}

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Monthly Restoration Log</h2>
        <DataTable
          rows={restoration}
          columns={restorationColumns}
          emptyMessage="No restoration months logged yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Stress vs Creative Trend</h2>
        <DataTable
          rows={trend}
          columns={trendColumns}
          emptyMessage="No trend data yet."
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Restoration Intentions</h2>
        <DataTable
          rows={intentions}
          columns={intentionColumns}
          emptyMessage="No intentions logged yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Intention Completion Summary</h2>
        <DataTable
          rows={completion}
          columns={completionColumns}
          emptyMessage="No completion data yet."
          rowKey={(r: any, i: number) => String(r.intention_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Top Restorers</h2>
        <DataTable
          rows={restorers}
          columns={restorerColumns}
          emptyMessage="No restorers logged yet."
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Top Drains</h2>
        <DataTable
          rows={drains}
          columns={drainColumns}
          emptyMessage="No drains logged yet."
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>
    </div>
  );
}
