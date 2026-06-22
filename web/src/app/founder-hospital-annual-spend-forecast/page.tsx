import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [forecasts, topOverruns, recentReviews] = await Promise.all([
    sb.rpc('list_forecasts_r1931'),
    sb.rpc('top_overrun_forecasts_r1931'),
    sb.rpc('recent_reviews_r1931'),
  ]);

  const forecastRows: any[] = Array.isArray(forecasts.data) ? forecasts.data : [];
  const overrunRows: any[] = Array.isArray(topOverruns.data) ? topOverruns.data : [];
  const reviewRows: any[] = Array.isArray(recentReviews.data) ? recentReviews.data : [];

  const forecastCols: Column<any>[] = [
    { key: 'fiscal_year', header: 'Fiscal Year', render: (r: any) => String(r.fiscal_year ?? '') },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'forecast_amount_rupees', header: 'Forecast (rupees)', render: (r: any) => Number(r.forecast_amount_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'actual_spend_rupees', header: 'Actual (rupees)', render: (r: any) => Number(r.actual_spend_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'variance_pct', header: 'Variance pct', render: (r: any) => `${Number(r.variance_pct ?? 0).toFixed(2)}%` },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'forecasted_at', header: 'Forecasted At', render: (r: any) => r.forecasted_at ? new Date(r.forecasted_at).toLocaleString() : '' },
    { key: 'closed_at', header: 'Closed At', render: (r: any) => r.closed_at ? new Date(r.closed_at).toLocaleString() : '' },
  ];

  const overrunCols: Column<any>[] = [
    { key: 'fiscal_year', header: 'Fiscal Year', render: (r: any) => String(r.fiscal_year ?? '') },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'forecast_amount_rupees', header: 'Forecast (rupees)', render: (r: any) => Number(r.forecast_amount_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'actual_spend_rupees', header: 'Actual (rupees)', render: (r: any) => Number(r.actual_spend_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'variance_pct', header: 'Overrun pct', render: (r: any) => `${Number(r.variance_pct ?? 0).toFixed(2)}%` },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const reviewCols: Column<any>[] = [
    { key: 'forecast_id', header: 'Forecast', render: (r: any) => String(r.forecast_id ?? '').slice(0, 8) },
    { key: 'review_type', header: 'Review Type', render: (r: any) => String(r.review_type ?? '') },
    { key: 'reviewed_at', header: 'Reviewed At', render: (r: any) => r.reviewed_at ? new Date(r.reviewed_at).toLocaleString() : '' },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'action_md', header: 'Action Notes', render: (r: any) => String(r.action_md ?? '').slice(0, 120) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital Annual Spend Forecast</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track forecasted vs actual annual spend per hospital. Variance greater than zero indicates overrun.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          All Forecasts ({forecastRows.length})
        </h2>
        <DataTable
          rows={forecastRows}
          columns={forecastCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Top Overrun Forecasts ({overrunRows.length})
        </h2>
        <p style={{ color: '#888', fontSize: 13, marginBottom: 8 }}>
          Sorted by variance percentage (highest overrun first).
        </p>
        <DataTable
          rows={overrunRows}
          columns={overrunCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Recent Reviews ({reviewRows.length})
        </h2>
        <DataTable
          rows={reviewRows}
          columns={reviewCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
