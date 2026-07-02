import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [forecastsRes, gapsRes, actionsRes] = await Promise.all([
    sb.rpc('list_forecasts_r2071'),
    sb.rpc('capacity_gaps_r2071'),
    sb.rpc('recent_actions_r2071'),
  ]);

  const forecasts: any[] = Array.isArray(forecastsRes.data) ? forecastsRes.data : [];
  const gaps: any[] = Array.isArray(gapsRes.data) ? gapsRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];

  const forecastCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'forecast_month_label', header: 'Month', render: (r: any) => String(r.forecast_month_label ?? '') },
    { key: 'predicted_demand_jobs', header: 'Predicted demand', render: (r: any) => String(r.predicted_demand_jobs ?? 0) },
    { key: 'available_capacity_jobs', header: 'Available capacity', render: (r: any) => String(r.available_capacity_jobs ?? 0) },
    { key: 'capacity_gap', header: 'Capacity gap', render: (r: any) => String(r.capacity_gap ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const gapCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'total_forecasts', header: 'Total forecasts', render: (r: any) => String(r.total_forecasts ?? 0) },
    { key: 'avg_gap', header: 'Avg gap', render: (r: any) => String(r.avg_gap ?? 0) },
    { key: 'max_gap', header: 'Max gap', render: (r: any) => String(r.max_gap ?? 0) },
    { key: 'latest_status', header: 'Latest status', render: (r: any) => String(r.latest_status ?? '') },
  ];

  const actionCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'forecast_month_label', header: 'Month', render: (r: any) => String(r.forecast_month_label ?? '') },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken at', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital Service Capacity Forecast</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Forecast service capacity needs per hospital. Track predicted demand against available capacity and log actions taken to close gaps.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Forecasts</h2>
        <DataTable
          rows={forecasts}
          columns={forecastCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Capacity gaps by hospital</h2>
        <DataTable
          rows={gaps}
          columns={gapCols}
          rowKey={(r: any, i: number) => String(r.hospital_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent actions</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
