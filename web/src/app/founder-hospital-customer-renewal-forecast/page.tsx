import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderHospitalCustomerRenewalForecastPage() {
  const sb = await getSupabaseServerClient();

  const { data: forecasts } = await sb.rpc('list_hospital_renewal_forecasts_r2011');
  const { data: highValue } = await sb.rpc('high_value_renewal_forecasts_r2011');
  const { data: recentActions } = await sb.rpc('recent_renewal_forecast_actions_r2011');

  const forecastRows: any[] = Array.isArray(forecasts) ? forecasts : [];
  const highValueRows: any[] = Array.isArray(highValue) ? highValue : [];
  const actionRows: any[] = Array.isArray(recentActions) ? recentActions : [];

  const forecastCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? r.hospital_id ?? '') },
    { key: 'renewal_due_date', header: 'Due Date', render: (r: any) => String(r.renewal_due_date ?? '') },
    { key: 'predicted_renewal_value_rupees', header: 'Predicted (rupees)', render: (r: any) => String(r.predicted_renewal_value_rupees ?? 0) },
    { key: 'actual_renewal_value_rupees', header: 'Actual (rupees)', render: (r: any) => String(r.actual_renewal_value_rupees ?? '-') },
    { key: 'renewal_probability_pct', header: 'Probability pct', render: (r: any) => String(r.renewal_probability_pct ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'forecasted_at', header: 'Forecasted At', render: (r: any) => String(r.forecasted_at ?? '') },
  ];

  const highValueCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? r.hospital_id ?? '') },
    { key: 'renewal_due_date', header: 'Due Date', render: (r: any) => String(r.renewal_due_date ?? '') },
    { key: 'predicted_renewal_value_rupees', header: 'Predicted (rupees)', render: (r: any) => String(r.predicted_renewal_value_rupees ?? 0) },
    { key: 'renewal_probability_pct', header: 'Probability pct', render: (r: any) => String(r.renewal_probability_pct ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const actionCols: Column<any>[] = [
    { key: 'forecast_id', header: 'Forecast', render: (r: any) => String(r.forecast_id ?? '') },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'taken_at', header: 'Taken At', render: (r: any) => String(r.taken_at ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Hospital Customer Renewal Forecast</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Renewal forecasting per hospital. Track predicted versus actual renewal value, probability, and engagement actions taken.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All Forecasts</h2>
        <DataTable rows={forecastRows} columns={forecastCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>High Value Forecasts</h2>
        <p style={{ color: '#666', marginBottom: 12, fontSize: 14 }}>
          Predicted value at least one lakh rupees and status remains forecast.
        </p>
        <DataTable rows={highValueRows} columns={highValueCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent Actions</h2>
        <DataTable rows={actionRows} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
