import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEnergyManagementTrackerPage() {
  const supabase = await getSupabaseServerClient();

  const [daily, patterns, weekly, peaks, exercise, sleep, pulse] = await Promise.all([
    supabase.rpc('list_daily_energy_r2493'),
    supabase.rpc('list_pattern_insights_r2493'),
    supabase.rpc('weekly_energy_trend_r2493'),
    supabase.rpc('peak_hours_breakdown_r2493'),
    supabase.rpc('exercise_vs_energy_r2493'),
    supabase.rpc('sleep_vs_energy_r2493'),
    supabase.rpc('monthly_pulse_summary_r2493'),
  ]);

  const dailyRows = (daily.data ?? []) as any[];
  const patternRows = (patterns.data ?? []) as any[];
  const weeklyRows = (weekly.data ?? []) as any[];
  const peakRows = (peaks.data ?? []) as any[];
  const exerciseRows = (exercise.data ?? []) as any[];
  const sleepRows = (sleep.data ?? []) as any[];
  const pulseRows = (pulse.data ?? []) as any[];

  const dailyCols: Column<any>[] = [
    { key: 'day', header: 'Day', render: (r: any) => String(r.day) },
    { key: 'sleep_hours', header: 'Sleep (h)', render: (r: any) => String(r.sleep_hours) },
    { key: 'exercise_minutes', header: 'Exercise (min)', render: (r: any) => String(r.exercise_minutes) },
    { key: 'nutrition_score', header: 'Nutrition', render: (r: any) => `${r.nutrition_score}/10` },
    { key: 'creative_block_minutes', header: 'Creative (min)', render: (r: any) => String(r.creative_block_minutes) },
    { key: 'energy_score', header: 'Energy', render: (r: any) => `${r.energy_score}/10` },
    { key: 'stress_score', header: 'Stress', render: (r: any) => `${r.stress_score}/10` },
    { key: 'peak_hours_md', header: 'Peak hours', render: (r: any) => r.peak_hours_md ?? '' },
    { key: 'low_hours_md', header: 'Low hours', render: (r: any) => r.low_hours_md ?? '' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const patternCols: Column<any>[] = [
    { key: 'pattern_kind', header: 'Pattern', render: (r: any) => String(r.pattern_kind) },
    { key: 'observed_count', header: 'Observed', render: (r: any) => String(r.observed_count) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '' },
    { key: 'action_md', header: 'Action', render: (r: any) => r.action_md ?? '' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const weeklyCols: Column<any>[] = [
    { key: 'week_start', header: 'Week start', render: (r: any) => String(r.week_start) },
    { key: 'avg_energy', header: 'Avg energy', render: (r: any) => String(r.avg_energy) },
    { key: 'avg_stress', header: 'Avg stress', render: (r: any) => String(r.avg_stress) },
    { key: 'avg_sleep', header: 'Avg sleep (h)', render: (r: any) => String(r.avg_sleep) },
    { key: 'days_logged', header: 'Days logged', render: (r: any) => String(r.days_logged) },
  ];

  const peakCols: Column<any>[] = [
    { key: 'pattern_kind', header: 'Pattern', render: (r: any) => String(r.pattern_kind) },
    { key: 'observed_count', header: 'Observed', render: (r: any) => String(r.observed_count) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status) },
    { key: 'action_md', header: 'Action', render: (r: any) => r.action_md ?? '' },
  ];

  const exerciseCols: Column<any>[] = [
    { key: 'exercise_bucket', header: 'Exercise bucket', render: (r: any) => String(r.exercise_bucket) },
    { key: 'days_count', header: 'Days', render: (r: any) => String(r.days_count) },
    { key: 'avg_energy', header: 'Avg energy', render: (r: any) => String(r.avg_energy) },
    { key: 'avg_stress', header: 'Avg stress', render: (r: any) => String(r.avg_stress) },
  ];

  const sleepCols: Column<any>[] = [
    { key: 'sleep_bucket', header: 'Sleep bucket', render: (r: any) => String(r.sleep_bucket) },
    { key: 'days_count', header: 'Days', render: (r: any) => String(r.days_count) },
    { key: 'avg_energy', header: 'Avg energy', render: (r: any) => String(r.avg_energy) },
    { key: 'avg_stress', header: 'Avg stress', render: (r: any) => String(r.avg_stress) },
  ];

  const pulseCols: Column<any>[] = [
    { key: 'metric', header: 'Metric', render: (r: any) => String(r.metric) },
    { key: 'value', header: 'Value', render: (r: any) => String(r.value) },
    { key: 'detail', header: 'Detail', render: (r: any) => String(r.detail) },
  ];

  return (
    <main style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 32 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Founder energy management tracker</h1>
        <p style={{ color: '#555', marginTop: 4 }}>
          Daily energy & sleep & exercise & nutrition =&gt; peak hours, low hours, and pattern actions.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Monthly pulse summary (30d)</h2>
        <DataTable
          rows={pulseRows}
          columns={pulseCols}
          emptyMessage="No pulse data yet."
          rowKey={(r: any, i: number) => String(r.metric ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Daily energy log</h2>
        <DataTable
          rows={dailyRows}
          columns={dailyCols}
          emptyMessage="No daily logs yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Pattern insights & actions</h2>
        <DataTable
          rows={patternRows}
          columns={patternCols}
          emptyMessage="No patterns detected yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Weekly energy trend</h2>
        <DataTable
          rows={weeklyRows}
          columns={weeklyCols}
          emptyMessage="Not enough days logged for weekly trend."
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Peak hours breakdown</h2>
        <DataTable
          rows={peakRows}
          columns={peakCols}
          emptyMessage="No peak-hour patterns yet."
          rowKey={(r: any, i: number) => String(r.pattern_kind ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Exercise vs energy</h2>
        <DataTable
          rows={exerciseRows}
          columns={exerciseCols}
          emptyMessage="No exercise correlation data yet."
          rowKey={(r: any, i: number) => String(r.exercise_bucket ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Sleep vs energy</h2>
        <DataTable
          rows={sleepRows}
          columns={sleepCols}
          emptyMessage="No sleep correlation data yet."
          rowKey={(r: any, i: number) => String(r.sleep_bucket ?? i)}
        />
      </section>
    </main>
  );
}
