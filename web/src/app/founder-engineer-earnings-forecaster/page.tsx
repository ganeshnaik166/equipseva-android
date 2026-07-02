import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

type Kpi = { label: string; value: string };

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function fmtPct(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return Number(n).toFixed(1) + '%';
}

export default async function FounderEngineerEarningsForecasterPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let summary: any = null;
  let topForecasts: any[] = [];
  let cliffs: any[] = [];
  let tierBreakdown: any[] = [];
  let openAlerts: any[] = [];

  try {
    const { data } = await sb.rpc('founder_eef_v2_summary');
    summary = Array.isArray(data) ? data[0] : data;
  } catch (_e) { summary = null; }

  try {
    const { data } = await sb.rpc('founder_eef_v2_top_forecasts', { p_limit: 50 });
    topForecasts = Array.isArray(data) ? data : [];
  } catch (_e) { topForecasts = []; }

  try {
    const { data } = await sb.rpc('founder_eef_v2_cliffs', { p_limit: 50 });
    cliffs = Array.isArray(data) ? data : [];
  } catch (_e) { cliffs = []; }

  try {
    const { data } = await sb.rpc('founder_eef_v2_tier_breakdown');
    tierBreakdown = Array.isArray(data) ? data : [];
  } catch (_e) { tierBreakdown = []; }

  try {
    const { data } = await sb.rpc('founder_eef_v2_open_cliff_alerts', { p_limit: 50 });
    openAlerts = Array.isArray(data) ? data : [];
  } catch (_e) { openAlerts = []; }

  const totalForecast = Number(summary?.total_forecast_rupees ?? 0);
  const totalPrior = Number(summary?.total_prior_rupees ?? 0);
  const delta = Number(summary?.forecast_delta_rupees ?? 0);
  const deltaPct = totalPrior > 0 ? (delta / totalPrior) * 100 : 0;
  const totalEngineers = Number(summary?.total_engineers ?? 0);
  const cliffCount = Number(summary?.cliff_count ?? 0);
  const cliffPct = totalEngineers > 0 ? (cliffCount / totalEngineers) * 100 : 0;
  const avgPerEngineer = totalEngineers > 0 ? totalForecast / totalEngineers : 0;
  const amcVisits = Number(summary?.amc_visits_total ?? 0);
  const tierCapTotal = Number(summary?.tier_cap_total ?? 0);
  const capUtilization = tierCapTotal > 0 ? (totalForecast / tierCapTotal) * 100 : 0;
  const avgDropPct = Number(summary?.avg_drop_pct ?? 0);
  const criticalCliffs = cliffs.filter((c: any) => c.severity === 'critical').length;
  const highCliffs = cliffs.filter((c: any) => c.severity === 'high').length;
  const openAlertCount = openAlerts.length;
  const topEarnerRupees = topForecasts[0]?.predicted_earnings_rupees ?? 0;
  const tierCount = tierBreakdown.length;
  const amcRevenue = amcVisits * 1500;

  const kpis: Kpi[] = [
    { label: 'Forecast Total (next month)', value: fmtRupees(totalForecast) },
    { label: 'Prior Month Total', value: fmtRupees(totalPrior) },
    { label: 'Forecast Delta', value: fmtRupees(delta) },
    { label: 'Delta %', value: fmtPct(deltaPct) },
    { label: 'Engineers Forecasted', value: String(totalEngineers) },
    { label: 'Avg / Engineer', value: fmtRupees(avgPerEngineer) },
    { label: 'Cliff Engineers', value: String(cliffCount) },
    { label: 'Cliff %', value: fmtPct(cliffPct) },
    { label: 'Critical Cliffs', value: String(criticalCliffs) },
    { label: 'High Cliffs', value: String(highCliffs) },
    { label: 'Open Alerts', value: String(openAlertCount) },
    { label: 'AMC Visits Scheduled', value: String(amcVisits) },
    { label: 'AMC Revenue (forecast)', value: fmtRupees(amcRevenue) },
    { label: 'Tier Cap Total', value: fmtRupees(tierCapTotal) },
    { label: 'Cap Utilization', value: fmtPct(capUtilization) },
    { label: 'Avg Drop %', value: fmtPct(avgDropPct) },
  ];

  const topCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? '—' },
    { key: 'tier', header: 'Tier', render: (r: any) => r.tier ?? '—' },
    { key: 'predicted_earnings_rupees', header: 'Forecast', render: (r: any) => fmtRupees(r.predicted_earnings_rupees) },
    { key: 'prior_month_earnings_rupees', header: 'Prior', render: (r: any) => fmtRupees(r.prior_month_earnings_rupees) },
    { key: 'drop_pct', header: 'Drop %', render: (r: any) => fmtPct(r.drop_pct) },
    { key: 'amc_visits_scheduled', header: 'AMC Visits', render: (r: any) => String(r.amc_visits_scheduled ?? 0) },
    { key: 'tier_cap_rupees', header: 'Cap', render: (r: any) => fmtRupees(r.tier_cap_rupees) },
    { key: 'is_cliff', header: 'Cliff', render: (r: any) => (r.is_cliff ? 'YES' : '—') },
  ];

  const cliffCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? '—' },
    { key: 'tier', header: 'Tier', render: (r: any) => r.tier ?? '—' },
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity ?? '—' },
    { key: 'drop_pct', header: 'Drop %', render: (r: any) => fmtPct(r.drop_pct) },
    { key: 'prior_month_earnings_rupees', header: 'Prior', render: (r: any) => fmtRupees(r.prior_month_earnings_rupees) },
    { key: 'predicted_earnings_rupees', header: 'Forecast', render: (r: any) => fmtRupees(r.predicted_earnings_rupees) },
  ];

  const tierCols: Column<any>[] = [
    { key: 'tier', header: 'Tier', render: (r: any) => r.tier ?? '—' },
    { key: 'engineer_count', header: 'Engineers', render: (r: any) => String(r.engineer_count ?? 0) },
    { key: 'forecast_total_rupees', header: 'Forecast', render: (r: any) => fmtRupees(r.forecast_total_rupees) },
    { key: 'prior_total_rupees', header: 'Prior', render: (r: any) => fmtRupees(r.prior_total_rupees) },
    { key: 'avg_drop_pct', header: 'Avg Drop %', render: (r: any) => fmtPct(r.avg_drop_pct) },
    { key: 'cliff_count', header: 'Cliffs', render: (r: any) => String(r.cliff_count ?? 0) },
  ];

  const alertCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? '—' },
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity ?? '—' },
    { key: 'drop_pct', header: 'Drop %', render: (r: any) => fmtPct(r.drop_pct) },
    { key: 'age_hours', header: 'Age (hrs)', render: (r: any) => (r.age_hours == null ? '—' : Number(r.age_hours).toFixed(1)) },
    { key: 'created_at', header: 'Created', render: (r: any) => (r.created_at ? new Date(r.created_at).toLocaleString() : '—') },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'ui-sans-serif, system-ui' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Engineer Earnings Forecaster v2</h1>
      <p style={{ color: '#555', marginBottom: 20 }}>
        Predicts next-month earnings using rolling 90d trend + AMC visits scheduled, capped by tier. Flags drops {">"} 30%.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        {kpis.map((k) => (
          <div key={k.label} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 11, color: '#6b7280', textTransform: 'uppercase' }}>{k.label}</div>
            <div style={{ fontSize: 18, fontWeight: 600, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </div>

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Top Forecast Earners</h2>
      <DataTable<any> rows={topForecasts} columns={topCols} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Earnings Cliffs (drop {">"} 30%)</h2>
      <DataTable<any> rows={cliffs} columns={cliffCols} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Tier Breakdown</h2>
      <DataTable<any> rows={tierBreakdown} columns={tierCols} rowKey={(r: any) => r.tier} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Open Cliff Alerts</h2>
      <DataTable<any> rows={openAlerts} columns={alertCols} rowKey={(r: any) => r.id} />
    </div>
  );
}
