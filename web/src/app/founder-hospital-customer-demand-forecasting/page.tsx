import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function HospitalCustomerDemandForecastingPage() {
  const sb = await getSupabaseServerClient();

  const [forecastsRes, accurateRes, recentActionsRes] = await Promise.all([
    sb.rpc('list_forecasts_r2135'),
    sb.rpc('accurate_forecasts_r2135'),
    sb.rpc('recent_actions_r2135'),
  ]);

  const forecasts: any[] = Array.isArray(forecastsRes.data) ? forecastsRes.data : [];
  const accurate: any[] = Array.isArray(accurateRes.data) ? accurateRes.data : [];
  const recentActions: any[] = Array.isArray(recentActionsRes.data) ? recentActionsRes.data : [];

  const forecastCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => String(r.quarter_label ?? '') },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'predicted_demand_jobs', header: 'Predicted Jobs', render: (r: any) => String(r.predicted_demand_jobs ?? 0) },
    { key: 'actual_demand_jobs', header: 'Actual Jobs', render: (r: any) => String(r.actual_demand_jobs ?? 0) },
    { key: 'forecast_error_pct', header: 'Error pct', render: (r: any) => `${Number(r.forecast_error_pct ?? 0).toFixed(2)}%` },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const accurateCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => String(r.quarter_label ?? '') },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'predicted_demand_jobs', header: 'Predicted', render: (r: any) => String(r.predicted_demand_jobs ?? 0) },
    { key: 'actual_demand_jobs', header: 'Actual', render: (r: any) => String(r.actual_demand_jobs ?? 0) },
    { key: 'forecast_error_pct', header: 'Error pct', render: (r: any) => `${Number(r.forecast_error_pct ?? 0).toFixed(2)}%` },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'forecast_id', header: 'Forecast', render: (r: any) => String(r.forecast_id ?? '').slice(0, 8) },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Customer Demand Forecasting</h1>
        <p className="text-sm text-gray-600">Quarterly demand forecasts per hospital with predicted vs actual job volume and error percentage tracking.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Forecasts</h2>
        <p className="text-xs text-gray-500 mb-2">Status flows from forecast to actualized or superseded. Error pct is signed delta of actual minus predicted over predicted.</p>
        <DataTable rows={forecasts} columns={forecastCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Accurate Forecasts (error pct at most 10)</h2>
        <p className="text-xs text-gray-500 mb-2">Actualized forecasts where the model came within ten percent. Ranked by lowest error first.</p>
        <DataTable rows={accurate} columns={accurateCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Actions</h2>
        <p className="text-xs text-gray-500 mb-2">Recent capacity adjustments, engineer additions, escalations, and actualizations across all forecasts.</p>
        <DataTable rows={recentActions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
