import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [forecastsRes, accurateRes, recentActionsRes] = await Promise.all([
    sb.rpc('list_forecasts_r1995'),
    sb.rpc('accurate_forecasts_r1995'),
    sb.rpc('recent_actions_r1995'),
  ]);

  const forecasts: any[] = Array.isArray(forecastsRes.data) ? forecastsRes.data : [];
  const accurate: any[] = Array.isArray(accurateRes.data) ? accurateRes.data : [];
  const recent: any[] = Array.isArray(recentActionsRes.data) ? recentActionsRes.data : [];

  const forecastCols: Column<any>[] = [
    { key: 'forecast_month', header: 'Month', render: (r: any) => String(r.forecast_month ?? '') },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'predicted_repeat_count', header: 'Predicted Repeats', render: (r: any) => String(r.predicted_repeat_count ?? 0) },
    { key: 'predicted_revenue_rupees', header: 'Predicted Revenue', render: (r: any) => `Rs ${Number(r.predicted_revenue_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'actual_repeat_count', header: 'Actual', render: (r: any) => r.actual_repeat_count == null ? 'pending' : String(r.actual_repeat_count) },
    { key: 'accuracy_pct', header: 'Accuracy', render: (r: any) => r.accuracy_pct == null ? '-' : `${Number(r.accuracy_pct).toFixed(1)}%` },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'generated_at', header: 'Generated', render: (r: any) => r.generated_at ? new Date(r.generated_at).toLocaleString() : '' },
  ];

  const accurateCols: Column<any>[] = [
    { key: 'forecast_month', header: 'Month', render: (r: any) => String(r.forecast_month ?? '') },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'predicted_repeat_count', header: 'Predicted', render: (r: any) => String(r.predicted_repeat_count ?? 0) },
    { key: 'actual_repeat_count', header: 'Actual', render: (r: any) => String(r.actual_repeat_count ?? 0) },
    { key: 'accuracy_pct', header: 'Accuracy', render: (r: any) => `${Number(r.accuracy_pct ?? 0).toFixed(1)}%` },
  ];

  const actionCols: Column<any>[] = [
    { key: 'taken_at', header: 'When', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'forecast_id', header: 'Forecast', render: (r: any) => String(r.forecast_id ?? '').slice(0, 8) },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 80) },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Hospital Repeat Bookings Forecast</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Next-month repeat booking predictions per hospital. Track accuracy and log engagement actions for accounts at risk.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All Forecasts ({forecasts.length})</h2>
        <DataTable rows={forecasts} columns={forecastCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Accurate Forecasts (accuracy at least 80 percent)</h2>
        <DataTable rows={accurate} columns={accurateCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent Actions ({recent.length})</h2>
        <DataTable rows={recent} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
