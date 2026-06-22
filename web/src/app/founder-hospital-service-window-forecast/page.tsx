import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [forecastsRes, peaksRes, actionsRes] = await Promise.all([
    sb.rpc('list_forecasts_r1899'),
    sb.rpc('peak_demand_weeks_r1899'),
    sb.rpc('recent_capacity_actions_r1899'),
  ]);

  const forecasts: any[] = Array.isArray(forecastsRes.data) ? forecastsRes.data : [];
  const peaks: any[] = Array.isArray(peaksRes.data) ? peaksRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];

  const totalForecasts = forecasts.length;
  const avgUtil = forecasts.length
    ? (forecasts.reduce((s, r) => s + Number(r.capacity_utilization_pct || 0), 0) / forecasts.length).toFixed(1)
    : '0.0';
  const overCapacity = forecasts.filter((r) => Number(r.capacity_utilization_pct || 0) > 100).length;
  const actualized = forecasts.filter((r) => r.status === 'actualized').length;

  const forecastCols: Column<any>[] = [
    { key: 'forecast_week_start', header: 'Week Start', render: (r: any) => String(r.forecast_week_start ?? '') },
    { key: 'predicted_jobs', header: 'Pred Jobs', render: (r: any) => String(r.predicted_jobs ?? 0) },
    { key: 'predicted_engineer_hours', header: 'Pred Hours', render: (r: any) => String(r.predicted_engineer_hours ?? 0) },
    { key: 'capacity_engineers', header: 'Capacity Eng', render: (r: any) => String(r.capacity_engineers ?? 0) },
    { key: 'capacity_utilization_pct', header: 'Util %', render: (r: any) => `${Number(r.capacity_utilization_pct ?? 0).toFixed(1)}%` },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'generated_at', header: 'Generated', render: (r: any) => r.generated_at ? new Date(r.generated_at).toLocaleString() : '' },
  ];

  const peakCols: Column<any>[] = [
    { key: 'forecast_week_start', header: 'Week Start', render: (r: any) => String(r.forecast_week_start ?? '') },
    { key: 'predicted_jobs', header: 'Pred Jobs', render: (r: any) => String(r.predicted_jobs ?? 0) },
    { key: 'capacity_utilization_pct', header: 'Util %', render: (r: any) => `${Number(r.capacity_utilization_pct ?? 0).toFixed(1)}%` },
  ];

  const actionCols: Column<any>[] = [
    { key: 'forecast_week_start', header: 'Week', render: (r: any) => String(r.forecast_week_start ?? '') },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'taken_at', header: 'Taken At', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: '1200px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '8px' }}>
        Hospital Service Window Forecast
      </h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        4-week forecast of service window demand & capacity utilization.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '12px', marginBottom: '24px' }}>
        <div style={{ padding: '16px', border: '1px solid #ddd', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Total Forecasts</div>
          <div style={{ fontSize: '22px', fontWeight: 700 }}>{totalForecasts}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #ddd', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Avg Utilization</div>
          <div style={{ fontSize: '22px', fontWeight: 700 }}>{avgUtil}%</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #ddd', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Over Capacity (&gt;100%)</div>
          <div style={{ fontSize: '22px', fontWeight: 700 }}>{overCapacity}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #ddd', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Actualized</div>
          <div style={{ fontSize: '22px', fontWeight: 700 }}>{actualized}</div>
        </div>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>4-Week Forecast</h2>
        <DataTable rows={forecasts} columns={forecastCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Peak Demand Weeks</h2>
        <p style={{ color: '#666', marginBottom: '8px', fontSize: '13px' }}>
          Weeks where utilization &gt;= 80% need capacity action.
        </p>
        <DataTable rows={peaks} columns={peakCols} rowKey={(r: any, i: number) => String(r.forecast_week_start ?? i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Recent Capacity Actions</h2>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
