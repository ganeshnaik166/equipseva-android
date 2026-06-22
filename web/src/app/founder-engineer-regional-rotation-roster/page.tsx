import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [kpisRes, regionRes, shiftRes, currentRes, fairnessRes, balanceRes, trendRes] = await Promise.all([
    sb.rpc('founder_engineer_rotation_kpis_r2274'),
    sb.rpc('founder_engineer_rotation_by_region_r2274'),
    sb.rpc('founder_engineer_rotation_by_shift_r2274'),
    sb.rpc('founder_engineer_rotation_current_week_r2274'),
    sb.rpc('founder_engineer_rotation_fairness_rank_r2274'),
    sb.rpc('founder_engineer_rotation_balance_log_r2274'),
    sb.rpc('founder_engineer_rotation_weekly_trend_r2274'),
  ]);

  const kpis = (kpisRes.data?.[0] ?? {}) as Record<string, unknown>;
  const regionRows = (regionRes.data ?? []) as Array<Record<string, unknown>>;
  const shiftRows = (shiftRes.data ?? []) as Array<Record<string, unknown>>;
  const currentRows = (currentRes.data ?? []) as Array<Record<string, unknown>>;
  const fairnessRows = (fairnessRes.data ?? []) as Array<Record<string, unknown>>;
  const balanceRows = (balanceRes.data ?? []) as Array<Record<string, unknown>>;
  const trendRows = (trendRes.data ?? []) as Array<Record<string, unknown>>;

  const regionCols: Column<any>[] = [
    { key: 'region', header: 'Region', render: (r) => String(r.region ?? '') },
    { key: 'engineers', header: 'Engineers', render: (r) => String(r.engineers ?? 0) },
    { key: 'total_jobs', header: 'Total jobs', render: (r) => String(r.total_jobs ?? 0) },
    { key: 'total_hours', header: 'Total hours', render: (r) => String(r.total_hours ?? 0) },
    { key: 'avg_fairness', header: 'Avg fairness', render: (r) => Number(r.avg_fairness ?? 0).toFixed(2) },
  ];

  const shiftCols: Column<any>[] = [
    { key: 'shift_type', header: 'Shift', render: (r) => String(r.shift_type ?? '') },
    { key: 'rows_count', header: 'Rows', render: (r) => String(r.rows_count ?? 0) },
    { key: 'on_duty_count', header: 'On duty', render: (r) => String(r.on_duty_count ?? 0) },
    { key: 'total_hours', header: 'Hours', render: (r) => String(r.total_hours ?? 0) },
    { key: 'total_jobs', header: 'Jobs', render: (r) => String(r.total_jobs ?? 0) },
  ];

  const currentCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r) => String(r.engineer_email ?? '') },
    { key: 'region', header: 'Region', render: (r) => String(r.region ?? '') },
    { key: 'shift_type', header: 'Shift', render: (r) => String(r.shift_type ?? '') },
    { key: 'week_start_date', header: 'Week start', render: (r) => String(r.week_start_date ?? '') },
    { key: 'week_end_date', header: 'Week end', render: (r) => String(r.week_end_date ?? '') },
    { key: 'jobs_assigned_count', header: 'Jobs', render: (r) => String(r.jobs_assigned_count ?? 0) },
    { key: 'hours_logged', header: 'Hours', render: (r) => String(r.hours_logged ?? 0) },
    { key: 'fairness_score', header: 'Fairness', render: (r) => Number(r.fairness_score ?? 0).toFixed(2) },
  ];

  const fairnessCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r) => String(r.engineer_email ?? '') },
    { key: 'region', header: 'Region', render: (r) => String(r.region ?? '') },
    { key: 'total_jobs', header: 'Jobs', render: (r) => String(r.total_jobs ?? 0) },
    { key: 'total_hours', header: 'Hours', render: (r) => String(r.total_hours ?? 0) },
    { key: 'avg_fairness_score', header: 'Avg fairness', render: (r) => Number(r.avg_fairness_score ?? 0).toFixed(2) },
    { key: 'balance_total', header: 'Balance', render: (r) => Number(r.balance_total ?? 0).toFixed(2) },
  ];

  const balanceCols: Column<any>[] = [
    { key: 'event_date', header: 'Date', render: (r) => String(r.event_date ?? '') },
    { key: 'engineer_email', header: 'Engineer', render: (r) => String(r.engineer_email ?? '') },
    { key: 'region', header: 'Region', render: (r) => String(r.region ?? '') },
    { key: 'shift_type', header: 'Shift', render: (r) => String(r.shift_type ?? '') },
    { key: 'delta_points', header: 'Delta', render: (r) => Number(r.delta_points ?? 0).toFixed(2) },
    { key: 'running_balance', header: 'Balance', render: (r) => Number(r.running_balance ?? 0).toFixed(2) },
    { key: 'reason', header: 'Reason', render: (r) => String(r.reason ?? '') },
  ];

  const trendCols: Column<any>[] = [
    { key: 'week_start_date', header: 'Week start', render: (r) => String(r.week_start_date ?? '') },
    { key: 'rows_count', header: 'Rows', render: (r) => String(r.rows_count ?? 0) },
    { key: 'on_duty_count', header: 'On duty', render: (r) => String(r.on_duty_count ?? 0) },
    { key: 'total_hours', header: 'Hours', render: (r) => String(r.total_hours ?? 0) },
    { key: 'total_jobs', header: 'Jobs', render: (r) => String(r.total_jobs ?? 0) },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 22, marginBottom: 6 }}>Engineer regional rotation roster</h1>
      <p style={{ color: '#555', marginBottom: 16 }}>
        Fair rotation across nights, weekends & holidays. Current weeks of duty plus balance log.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 20 }}>
        <Kpi label="Active engineers" value={String(kpis.active_engineers ?? 0)} />
        <Kpi label="On duty this week" value={String(kpis.on_duty_this_week ?? 0)} />
        <Kpi label="Hours last week" value={String(kpis.total_hours_last_week ?? 0)} />
        <Kpi label="Avg fairness" value={Number(kpis.avg_fairness_score ?? 0).toFixed(2)} />
        <Kpi label="Night shifts" value={String(kpis.night_shift_count ?? 0)} />
        <Kpi label="Weekend shifts" value={String(kpis.weekend_shift_count ?? 0)} />
        <Kpi label="Holiday shifts" value={String(kpis.holiday_shift_count ?? 0)} />
      </section>

      <h2 style={{ fontSize: 16, marginTop: 16, marginBottom: 8 }}>By region</h2>
      <DataTable columns={regionCols} rows={regionRows} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: 16, marginTop: 16, marginBottom: 8 }}>By shift type</h2>
      <DataTable columns={shiftCols} rows={shiftRows} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: 16, marginTop: 16, marginBottom: 8 }}>Current week duty</h2>
      <DataTable columns={currentCols} rows={currentRows} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: 16, marginTop: 16, marginBottom: 8 }}>Fairness ranking</h2>
      <DataTable columns={fairnessCols} rows={fairnessRows} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: 16, marginTop: 16, marginBottom: 8 }}>Balance log (last 50)</h2>
      <DataTable columns={balanceCols} rows={balanceRows} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: 16, marginTop: 16, marginBottom: 8 }}>Weekly trend</h2>
      <DataTable columns={trendCols} rows={trendRows} rowKey={(_, i) => String(i)} />
    </div>
  );
}

function Kpi({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fafafa' }}>
      <div style={{ fontSize: 12, color: '#6b7280' }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 600, marginTop: 4 }}>{value}</div>
    </div>
  );
}
