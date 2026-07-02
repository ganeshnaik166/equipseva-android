import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderWeeklyOutcomesRetroPage() {
  const supabase = await getSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  const email = user?.email ?? '';

  const [kpi, weekly, current, byCat, blockers, lessons, streaks] = await Promise.all([
    supabase.rpc('founder_retro_kpi_r2361'),
    supabase.rpc('founder_retro_week_summary_r2361', { p_weeks: 12 }),
    supabase.rpc('founder_retro_current_week_r2361'),
    supabase.rpc('founder_retro_category_hitrate_r2361'),
    supabase.rpc('founder_retro_blocking_factors_r2361'),
    supabase.rpc('founder_retro_recent_lessons_r2361'),
    supabase.rpc('founder_retro_missed_streak_r2361'),
  ]);

  const k = (kpi.data ?? [])[0] ?? {};

  const weeklyCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r) => String(r.week_start ?? '') },
    { key: 'total_intentions', header: 'Intentions', render: (r) => String(r.total_intentions ?? 0) },
    { key: 'completed', header: 'Done', render: (r) => String(r.completed ?? 0) },
    { key: 'partial', header: 'Partial', render: (r) => String(r.partial ?? 0) },
    { key: 'missed', header: 'Missed', render: (r) => String(r.missed ?? 0) },
    { key: 'deferred', header: 'Deferred', render: (r) => String(r.deferred ?? 0) },
    { key: 'hit_rate', header: 'Hit %', render: (r) => String(r.hit_rate ?? '-') },
  ];

  const curCols: Column<any>[] = [
    { key: 'intention_title', header: 'Intention', render: (r) => String(r.intention_title ?? '') },
    { key: 'category', header: 'Category', render: (r) => String(r.category ?? '') },
    { key: 'priority', header: 'Pri', render: (r) => String(r.priority ?? '') },
    { key: 'success_metric', header: 'Metric', render: (r) => String(r.success_metric ?? '-') },
    { key: 'target_value', header: 'Target', render: (r) => String(r.target_value ?? '-') },
    { key: 'outcome_status', header: 'Status', render: (r) => String(r.outcome_status ?? 'pending') },
    { key: 'actual_value', header: 'Actual', render: (r) => String(r.actual_value ?? '-') },
    { key: 'gap_reason', header: 'Gap', render: (r) => String(r.gap_reason ?? '-') },
  ];

  const catCols: Column<any>[] = [
    { key: 'category', header: 'Category', render: (r) => String(r.category ?? '') },
    { key: 'total', header: 'Total', render: (r) => String(r.total ?? 0) },
    { key: 'completed', header: 'Done', render: (r) => String(r.completed ?? 0) },
    { key: 'hit_rate', header: 'Hit %', render: (r) => String(r.hit_rate ?? '-') },
  ];

  const blkCols: Column<any>[] = [
    { key: 'blocking_factor', header: 'Blocker', render: (r) => String(r.blocking_factor ?? '') },
    { key: 'occurrences', header: 'Times', render: (r) => String(r.occurrences ?? 0) },
    { key: 'last_seen', header: 'Last', render: (r) => String(r.last_seen ?? '') },
  ];

  const lesCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r) => String(r.week_start ?? '') },
    { key: 'intention_title', header: 'Intention', render: (r) => String(r.intention_title ?? '') },
    { key: 'lesson_learned', header: 'Lesson', render: (r) => String(r.lesson_learned ?? '') },
    { key: 'outcome_status', header: 'Status', render: (r) => String(r.outcome_status ?? '') },
  ];

  const strCols: Column<any>[] = [
    { key: 'intention_title', header: 'Intention', render: (r) => String(r.intention_title ?? '') },
    { key: 'category', header: 'Cat', render: (r) => String(r.category ?? '') },
    { key: 'consecutive_misses', header: 'Misses', render: (r) => String(r.consecutive_misses ?? 0) },
    { key: 'last_week', header: 'Last Week', render: (r) => String(r.last_week ?? '') },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Weekly Outcomes vs Intentions</h1>
      <p style={{ color: '#666', marginBottom: 16 }}>
        Founder retrospective — what you said you would do vs what got done. Signed in as {email || 'unknown'}.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 12, marginBottom: 20 }}>
        <Kpi label="Weeks tracked" value={String(k.total_weeks ?? 0)} />
        <Kpi label="Intentions" value={String(k.total_intentions ?? 0)} />
        <Kpi label="Hit rate %" value={String(k.overall_hit_rate ?? '-')} />
        <Kpi label="Avg/week" value={String(k.avg_intentions_per_week ?? '-')} />
        <Kpi label="Pending this wk" value={String(k.pending_current_week ?? 0)} />
      </section>

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '16px 0 8px' }}>Current week</h2>
      <DataTable rows={current.data ?? []} rowKey={(r: any) => String(r.id)} emptyMessage="No intentions declared this week" columns={curCols} />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '24px 0 8px' }}>Last 12 weeks</h2>
      <DataTable rows={weekly.data ?? []} rowKey={(r: any) => String(r.week_start)} emptyMessage="No history yet" columns={weeklyCols} />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '24px 0 8px' }}>Hit rate by category</h2>
      <DataTable rows={byCat.data ?? []} rowKey={(r: any) => String(r.category)} emptyMessage="No data" columns={catCols} />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '24px 0 8px' }}>Repeated blockers</h2>
      <DataTable rows={blockers.data ?? []} rowKey={(r: any) => String(r.blocking_factor)} emptyMessage="No blockers logged" columns={blkCols} />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '24px 0 8px' }}>Missed streaks (&gt;= 2)</h2>
      <DataTable rows={streaks.data ?? []} rowKey={(r: any) => String(r.intention_title)} emptyMessage="No repeated misses" columns={strCols} />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '24px 0 8px' }}>Recent lessons</h2>
      <DataTable rows={lessons.data ?? []} rowKey={(r: any) => String(r.week_start) + String(r.intention_title)} emptyMessage="No lessons captured yet" columns={lesCols} />
    </main>
  );
}

function Kpi({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fafafa' }}>
      <div style={{ fontSize: 11, color: '#666', textTransform: 'uppercase' }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>{value}</div>
    </div>
  );
}
