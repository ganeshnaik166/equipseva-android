import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [forecastsRes, actionsRes, accurateRes, recentRes] = await Promise.all([
    sb.rpc('list_forecasts_r2091'),
    sb.rpc('list_actions_r2091'),
    sb.rpc('accurate_forecasts_r2091'),
    sb.rpc('recent_actions_r2091'),
  ]);

  const forecasts = (forecastsRes.data as any[]) ?? [];
  const actions = (actionsRes.data as any[]) ?? [];
  const accurate = (accurateRes.data as any[]) ?? [];
  const recent = (recentRes.data as any[]) ?? [];

  const forecastColumns: Column<any>[] = [
    { key: 'forecast_period_label', header: 'Period', render: (r: any) => String(r.forecast_period_label ?? '') },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => String(r.hospital_email ?? '—') },
    { key: 'predicted_jobs', header: 'Predicted', render: (r: any) => String(r.predicted_jobs ?? 0) },
    { key: 'actual_jobs', header: 'Actual', render: (r: any) => String(r.actual_jobs ?? 0) },
    { key: 'accuracy_pct', header: 'Accuracy pct', render: (r: any) => r.accuracy_pct == null ? '—' : `${Number(r.accuracy_pct).toFixed(1)}%` },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '—' },
  ];

  const actionColumns: Column<any>[] = [
    { key: 'forecast_period', header: 'Period', render: (r: any) => String(r.forecast_period ?? '—') },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'taken_at', header: 'Taken at', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '—' },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '—') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '—') },
  ];

  const accurateColumns: Column<any>[] = [
    { key: 'forecast_period_label', header: 'Period', render: (r: any) => String(r.forecast_period_label ?? '') },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => String(r.hospital_email ?? '—') },
    { key: 'predicted_jobs', header: 'Predicted', render: (r: any) => String(r.predicted_jobs ?? 0) },
    { key: 'actual_jobs', header: 'Actual', render: (r: any) => String(r.actual_jobs ?? 0) },
    { key: 'accuracy_pct', header: 'Accuracy pct', render: (r: any) => r.accuracy_pct == null ? '—' : `${Number(r.accuracy_pct).toFixed(1)}%` },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '—' },
  ];

  const recentColumns: Column<any>[] = [
    { key: 'forecast_period', header: 'Period', render: (r: any) => String(r.forecast_period ?? '—') },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'taken_at', header: 'Taken at', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '—' },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '—') },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Repair Job Volume Forecast</h1>
        <p className="text-sm text-gray-600">
          Forecast repair job volume per hospital. Track predicted versus actual job counts and accuracy.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Forecasts</h2>
        <DataTable rows={forecasts} columns={forecastColumns} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Accurate Forecasts (accuracy 80 percent or higher)</h2>
        <DataTable rows={accurate} columns={accurateColumns} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Actions (last 30 days)</h2>
        <DataTable rows={recent} columns={recentColumns} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Action Log</h2>
        <DataTable rows={actions} columns={actionColumns} rowKey={(r, i) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
