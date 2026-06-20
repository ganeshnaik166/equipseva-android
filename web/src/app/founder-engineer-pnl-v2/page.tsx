import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '₹0';
  return '₹' + Number(n).toLocaleString('en-IN');
}

export default async function FounderEngineerPnlV2Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpiData: any = {};
  let cohortMatrix: any[] = [];
  let retentionCurves: any[] = [];
  let highLtv: any[] = [];
  let heatmap: any[] = [];
  let cohortTrend: any[] = [];

  try {
    const r = await sb.rpc('founder_engineer_pnl_v2_kpis');
    kpiData = r.data ?? {};
  } catch (_e) { kpiData = {}; }

  try {
    const r = await sb.rpc('founder_engineer_cohort_matrix');
    cohortMatrix = r.data ?? [];
  } catch (_e) { cohortMatrix = []; }

  try {
    const r = await sb.rpc('founder_engineer_retention_curves');
    retentionCurves = r.data ?? [];
  } catch (_e) { retentionCurves = []; }

  try {
    const r = await sb.rpc('founder_engineer_high_ltv_profiles');
    highLtv = r.data ?? [];
  } catch (_e) { highLtv = []; }

  try {
    const r = await sb.rpc('founder_engineer_tier_util_heatmap');
    heatmap = r.data ?? [];
  } catch (_e) { heatmap = []; }

  try {
    const r = await sb.rpc('founder_engineer_cohort_trend');
    cohortTrend = r.data ?? [];
  } catch (_e) { cohortTrend = []; }

  const kpis: Kpi[] = [
    { label: 'Total Engineers', value: String(kpiData.total_engineers ?? 0) },
    { label: 'Total Revenue', value: fmtRupees(kpiData.total_revenue_rupees) },
    { label: 'Total Payout', value: fmtRupees(kpiData.total_payout_rupees) },
    { label: 'Gross Margin', value: fmtRupees(kpiData.gross_margin_rupees) },
    { label: 'Distinct Cohorts', value: String(kpiData.distinct_cohorts ?? 0) },
    { label: 'Tiers Active', value: String(kpiData.tiers_active ?? 0) },
    { label: 'Avg Revenue/Eng', value: fmtRupees(kpiData.avg_revenue_per_eng) },
    { label: 'Avg Payout/Eng', value: fmtRupees(kpiData.avg_payout_per_eng) },
    { label: 'High-LTV Engineers', value: String(kpiData.high_ltv_count ?? 0) },
    { label: 'Avg LTV', value: fmtRupees(kpiData.avg_ltv_rupees) },
    { label: 'Top Cohort Month', value: String(kpiData.top_cohort_month ?? '—') },
    { label: 'Top Tier', value: String(kpiData.top_tier ?? '—') },
    { label: 'Snapshots Total', value: String(kpiData.snapshots_total ?? 0) },
    { label: 'LTV Profiles Total', value: String(kpiData.ltv_profiles_total ?? 0) },
    { label: 'Last Snapshot', value: String(kpiData.last_snapshot_at ?? '—').slice(0,10) },
    { label: 'Last LTV Refresh', value: String(kpiData.last_ltv_at ?? '—').slice(0,10) },
  ];

  const cohortCols: Column<any>[] = [
    { key: 'signup_month', header: 'Signup Month', render: (r: any) => r.signup_month ?? '—' },
    { key: 'current_tier', header: 'Tier', render: (r: any) => r.current_tier ?? '—' },
    { key: 'utilization_bucket', header: 'Utilization', render: (r: any) => r.utilization_bucket ?? '—' },
    { key: 'engineer_count', header: 'Engineers', render: (r: any) => String(r.engineer_count ?? 0) },
    { key: 'active_engineer_count', header: 'Active', render: (r: any) => String(r.active_engineer_count ?? 0) },
    { key: 'total_revenue_rupees', header: 'Revenue', render: (r: any) => fmtRupees(r.total_revenue_rupees) },
    { key: 'total_gross_margin_rupees', header: 'Margin', render: (r: any) => fmtRupees(r.total_gross_margin_rupees) },
    { key: 'avg_ltv_rupees', header: 'Avg LTV', render: (r: any) => fmtRupees(r.avg_ltv_rupees) },
    { key: 'avg_rating', header: 'Rating', render: (r: any) => (r.avg_rating != null ? Number(r.avg_rating).toFixed(2) : '—') },
  ];

  const retentionCols: Column<any>[] = [
    { key: 'signup_month', header: 'Cohort', render: (r: any) => r.signup_month ?? '—' },
    { key: 'cohort_size', header: 'Size', render: (r: any) => String(r.cohort_size ?? 0) },
    { key: 'm0_active', header: 'M0', render: (r: any) => String(r.m0_active ?? 0) },
    { key: 'm1_active', header: 'M1', render: (r: any) => String(r.m1_active ?? 0) },
    { key: 'm3_active', header: 'M3', render: (r: any) => String(r.m3_active ?? 0) },
    { key: 'm6_active', header: 'M6', render: (r: any) => String(r.m6_active ?? 0) },
    { key: 'm12_active', header: 'M12', render: (r: any) => String(r.m12_active ?? 0) },
    { key: 'retention_m6_pct', header: 'M6 Retention', render: (r: any) => (r.retention_m6_pct != null ? Number(r.retention_m6_pct).toFixed(1)+'%' : '—') },
  ];

  const highLtvCols: Column<any>[] = [
    { key: 'engineer_id', header: 'Engineer', render: (r: any) => String(r.engineer_id ?? '—').slice(0,8) },
    { key: 'signup_month', header: 'Signup', render: (r: any) => r.signup_month ?? '—' },
    { key: 'current_tier', header: 'Tier', render: (r: any) => r.current_tier ?? '—' },
    { key: 'months_active', header: 'Months', render: (r: any) => (r.months_active != null ? Number(r.months_active).toFixed(1) : '—') },
    { key: 'total_jobs', header: 'Jobs', render: (r: any) => String(r.total_jobs ?? 0) },
    { key: 'total_revenue_rupees', header: 'Revenue', render: (r: any) => fmtRupees(r.total_revenue_rupees) },
    { key: 'ltv_rupees', header: 'LTV', render: (r: any) => fmtRupees(r.ltv_rupees) },
    { key: 'ltv_percentile', header: 'Pct', render: (r: any) => (r.ltv_percentile != null ? Number(r.ltv_percentile).toFixed(1) : '—') },
    { key: 'utilization_pct', header: 'Util%', render: (r: any) => (r.utilization_pct != null ? Number(r.utilization_pct).toFixed(1) : '—') },
    { key: 'avg_rating', header: 'Rating', render: (r: any) => (r.avg_rating != null ? Number(r.avg_rating).toFixed(2) : '—') },
  ];

  const heatmapCols: Column<any>[] = [
    { key: 'current_tier', header: 'Tier', render: (r: any) => r.current_tier ?? '—' },
    { key: 'utilization_bucket', header: 'Utilization', render: (r: any) => r.utilization_bucket ?? '—' },
    { key: 'engineer_count', header: 'Engineers', render: (r: any) => String(r.engineer_count ?? 0) },
    { key: 'avg_ltv_rupees', header: 'Avg LTV', render: (r: any) => fmtRupees(r.avg_ltv_rupees) },
    { key: 'total_revenue_rupees', header: 'Revenue', render: (r: any) => fmtRupees(r.total_revenue_rupees) },
    { key: 'total_gross_margin_rupees', header: 'Margin', render: (r: any) => fmtRupees(r.total_gross_margin_rupees) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'signup_month', header: 'Month', render: (r: any) => r.signup_month ?? '—' },
    { key: 'cohort_size', header: 'Size', render: (r: any) => String(r.cohort_size ?? 0) },
    { key: 'avg_ltv_rupees', header: 'Avg LTV', render: (r: any) => fmtRupees(r.avg_ltv_rupees) },
    { key: 'total_gross_margin_rupees', header: 'Margin', render: (r: any) => fmtRupees(r.total_gross_margin_rupees) },
    { key: 'avg_rating', header: 'Rating', render: (r: any) => (r.avg_rating != null ? Number(r.avg_rating).toFixed(2) : '—') },
  ];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Engineer P&L v2 — Cohort Analysis</h1>
        <p className="text-sm text-gray-600">Signup-month × tier × utilization. Retention curves. High-LTV engineer profile.</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-8 gap-3">
        {kpis.map((k) => (
          <div key={k.label} className="rounded-lg border bg-white p-3">
            <div className="text-xs text-gray-500">{k.label}</div>
            <div className="text-lg font-semibold">{k.value}</div>
          </div>
        ))}
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Cohort Matrix (Signup × Tier × Utilization)</h2>
        <DataTable columns={cohortCols} rows={cohortMatrix} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Retention Curves by Cohort</h2>
        <DataTable columns={retentionCols} rows={retentionCurves} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">High-LTV Engineer Profiles</h2>
        <DataTable columns={highLtvCols} rows={highLtv} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Tier × Utilization Heatmap</h2>
        <DataTable columns={heatmapCols} rows={heatmap} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Cohort Trend (Last 24 Months)</h2>
        <DataTable columns={trendCols} rows={cohortTrend} rowKey={(r: any) => r.id} />
      </section>
    </div>
  );
}
