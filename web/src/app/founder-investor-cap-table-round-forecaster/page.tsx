import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [forecastsRes, modeledRes, recentRes] = await Promise.all([
    sb.rpc('list_forecasts_r1961'),
    sb.rpc('modeled_rounds_r1961'),
    sb.rpc('recent_scenarios_r1961'),
  ]);

  const forecasts: any[] = Array.isArray(forecastsRes.data) ? forecastsRes.data : [];
  const modeled: any[] = Array.isArray(modeledRes.data) ? modeledRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const forecastCols: Column<any>[] = [
    { key: 'round_label', header: 'Round', render: (r: any) => String(r.round_label ?? '') },
    { key: 'target_amount_rupees', header: 'Target (Rs)', render: (r: any) => Number(r.target_amount_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'projected_valuation_pre_money_rupees', header: 'Pre-money (Rs)', render: (r: any) => Number(r.projected_valuation_pre_money_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'projected_valuation_post_money_rupees', header: 'Post-money (Rs)', render: (r: any) => Number(r.projected_valuation_post_money_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'founder_dilution_pct', header: 'Founder dilution %', render: (r: any) => `${Number(r.founder_dilution_pct ?? 0).toFixed(2)}%` },
    { key: 'projected_close_date', header: 'Close date', render: (r: any) => r.projected_close_date ? String(r.projected_close_date) : '-' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'modeled_at', header: 'Modeled at', render: (r: any) => r.modeled_at ? new Date(r.modeled_at).toLocaleString('en-IN') : '-' },
  ];

  const modeledCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'round_count', header: 'Rounds', render: (r: any) => Number(r.round_count ?? 0).toLocaleString('en-IN') },
    { key: 'total_target_rupees', header: 'Total target (Rs)', render: (r: any) => Number(r.total_target_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'avg_dilution_pct', header: 'Avg dilution %', render: (r: any) => `${Number(r.avg_dilution_pct ?? 0).toFixed(2)}%` },
  ];

  const recentCols: Column<any>[] = [
    { key: 'round_label', header: 'Round', render: (r: any) => String(r.round_label ?? '') },
    { key: 'scenario_type', header: 'Scenario', render: (r: any) => String(r.scenario_type ?? '') },
    { key: 'projected_dilution_pct', header: 'Projected dilution %', render: (r: any) => `${Number(r.projected_dilution_pct ?? 0).toFixed(2)}%` },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '-') },
    { key: 'recorded_at', header: 'Recorded at', render: (r: any) => r.recorded_at ? new Date(r.recorded_at).toLocaleString('en-IN') : '-' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Investor Cap Table Round Forecaster</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Forecast cap-table dilution per planned round. Model best-case &amp; worst-case scenarios; track when projected close date &lt;= 90 days out.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Modeled rounds by status</h2>
        <DataTable rows={modeled} columns={modeledCols} rowKey={(r: any, i: number) => String(r.status ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Planned rounds</h2>
        <DataTable rows={forecasts} columns={forecastCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent scenario log</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
