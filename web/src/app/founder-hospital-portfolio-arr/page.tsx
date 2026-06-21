import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtINR(n: number | null | undefined): string {
  if (n === null || n === undefined || Number.isNaN(Number(n))) return '₹0';
  return '₹' + Number(n).toLocaleString('en-IN', { maximumFractionDigits: 0 });
}

function fmtNum(n: number | null | undefined): string {
  if (n === null || n === undefined) return '0';
  return Number(n).toLocaleString('en-IN');
}

function fmtPct(n: number | null | undefined): string {
  if (n === null || n === undefined) return '0%';
  return Number(n).toFixed(2) + '%';
}

export default async function HospitalPortfolioArrPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let summary: any = null;
  let tiers: any[] = [];
  let growth: any[] = [];
  let churn: any = null;
  let topHospitals: any[] = [];
  let snapshots: any[] = [];
  let reviews: any[] = [];

  try {
    const r = await sb.rpc('founder_arr_portfolio_summary');
    summary = Array.isArray(r.data) && r.data.length > 0 ? r.data[0] : null;
  } catch { summary = null; }

  try {
    const r = await sb.rpc('founder_arr_by_tier');
    tiers = Array.isArray(r.data) ? r.data : [];
  } catch { tiers = []; }

  try {
    const r = await sb.rpc('founder_arr_growth_rate');
    growth = Array.isArray(r.data) ? r.data : [];
  } catch { growth = []; }

  try {
    const r = await sb.rpc('founder_arr_churn_forecast');
    churn = Array.isArray(r.data) && r.data.length > 0 ? r.data[0] : null;
  } catch { churn = null; }

  try {
    const r = await sb.rpc('founder_arr_top_hospitals', { p_limit: 20 });
    topHospitals = Array.isArray(r.data) ? r.data : [];
  } catch { topHospitals = []; }

  try {
    const r = await sb.rpc('founder_arr_recent_snapshots', { p_limit: 12 });
    snapshots = Array.isArray(r.data) ? r.data : [];
  } catch { snapshots = []; }

  try {
    const r = await sb.rpc('founder_arr_recent_weekly_reviews', { p_limit: 12 });
    reviews = Array.isArray(r.data) ? r.data : [];
  } catch { reviews = []; }

  const totalArr = Number(summary?.total_arr_rupees ?? 0);
  const totalContracts = Number(summary?.total_active_contracts ?? 0);
  const avgContract = Number(summary?.avg_contract_rupees ?? 0);
  const started30d = Number(summary?.contracts_started_30d ?? 0);
  const started90d = Number(summary?.contracts_started_90d ?? 0);

  const growth30 = growth.find((g: any) => g.period_label === '0-30d');
  const growth60 = growth.find((g: any) => g.period_label === '31-60d');
  const growth90 = growth.find((g: any) => g.period_label === '61-90d');

  const tier1 = tiers[0];
  const tier2 = tiers[1];
  const tier3 = tiers[2];

  const kpis: Kpi[] = [
    { label: 'Total ARR', value: fmtINR(totalArr) },
    { label: 'Active Contracts', value: fmtNum(totalContracts) },
    { label: 'Avg Contract / yr', value: fmtINR(avgContract) },
    { label: 'Started (30d)', value: fmtNum(started30d) },
    { label: 'Started (90d)', value: fmtNum(started90d) },
    { label: 'Top Tier', value: tier1?.amc_tier ?? '—' },
    { label: 'Top Tier ARR', value: fmtINR(Number(tier1?.tier_arr_rupees ?? 0)) },
    { label: 'Top Tier Share', value: fmtPct(Number(tier1?.share_pct ?? 0)) },
    { label: '2nd Tier ARR', value: fmtINR(Number(tier2?.tier_arr_rupees ?? 0)) },
    { label: '3rd Tier ARR', value: fmtINR(Number(tier3?.tier_arr_rupees ?? 0)) },
    { label: 'Growth 0-30d', value: fmtPct(Number(growth30?.growth_pct ?? 0)) },
    { label: 'Growth 31-60d', value: fmtPct(Number(growth60?.growth_pct ?? 0)) },
    { label: 'Growth 61-90d', value: fmtPct(Number(growth90?.growth_pct ?? 0)) },
    { label: 'Churn rate (90d)', value: fmtPct(Number(churn?.churn_rate_pct ?? 0)) },
    { label: 'Forecast ARR 12mo', value: fmtINR(Number(churn?.forecast_arr_12mo_rupees ?? 0)) },
    { label: 'Forecast ARR loss', value: fmtINR(Number(churn?.forecast_arr_loss_rupees ?? 0)) },
  ];

  const tierCols: Column<any>[] = [
    { key: 'amc_tier', header: 'Tier', render: (r: any) => r.amc_tier ?? '—' },
    { key: 'contract_count', header: 'Contracts', render: (r: any) => fmtNum(Number(r.contract_count ?? 0)) },
    { key: 'tier_arr_rupees', header: 'ARR', render: (r: any) => fmtINR(Number(r.tier_arr_rupees ?? 0)) },
    { key: 'avg_monthly_fee', header: 'Avg Monthly', render: (r: any) => fmtINR(Number(r.avg_monthly_fee ?? 0)) },
    { key: 'share_pct', header: 'Share', render: (r: any) => fmtPct(Number(r.share_pct ?? 0)) },
  ];

  const growthCols: Column<any>[] = [
    { key: 'period_label', header: 'Period', render: (r: any) => r.period_label ?? '—' },
    { key: 'contracts_added', header: 'Contracts +', render: (r: any) => fmtNum(Number(r.contracts_added ?? 0)) },
    { key: 'arr_added_rupees', header: 'ARR +', render: (r: any) => fmtINR(Number(r.arr_added_rupees ?? 0)) },
    { key: 'growth_pct', header: 'Growth %', render: (r: any) => fmtPct(Number(r.growth_pct ?? 0)) },
  ];

  const hospitalCols: Column<any>[] = [
    { key: 'hospital_org_name', header: 'Hospital', render: (r: any) => r.hospital_org_name ?? '—' },
    { key: 'amc_tier', header: 'Tier', render: (r: any) => r.amc_tier ?? '—' },
    { key: 'monthly_fee_rupees', header: 'Monthly', render: (r: any) => fmtINR(Number(r.monthly_fee_rupees ?? 0)) },
    { key: 'annual_arr_rupees', header: 'Annual ARR', render: (r: any) => fmtINR(Number(r.annual_arr_rupees ?? 0)) },
    { key: 'contract_started_at', header: 'Started', render: (r: any) => r.contract_started_at ? new Date(r.contract_started_at).toLocaleDateString('en-IN') : '—' },
  ];

  const snapshotCols: Column<any>[] = [
    { key: 'snapshot_date', header: 'Date', render: (r: any) => r.snapshot_date ?? '—' },
    { key: 'total_active_contracts', header: 'Contracts', render: (r: any) => fmtNum(Number(r.total_active_contracts ?? 0)) },
    { key: 'total_arr_rupees', header: 'Total ARR', render: (r: any) => fmtINR(Number(r.total_arr_rupees ?? 0)) },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const reviewCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => r.week_start ?? '—' },
    { key: 'arr_opening_rupees', header: 'Opening ARR', render: (r: any) => fmtINR(Number(r.arr_opening_rupees ?? 0)) },
    { key: 'arr_closing_rupees', header: 'Closing ARR', render: (r: any) => fmtINR(Number(r.arr_closing_rupees ?? 0)) },
    { key: 'new_contracts', header: 'New', render: (r: any) => fmtNum(Number(r.new_contracts ?? 0)) },
    { key: 'churned_contracts', header: 'Churned', render: (r: any) => fmtNum(Number(r.churned_contracts ?? 0)) },
    { key: 'review_notes', header: 'Notes', render: (r: any) => r.review_notes ?? '—' },
  ];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-semibold">Hospital Portfolio ARR</h1>
        <p className="text-sm text-gray-600">Cumulative ARR, per-tier breakdown, growth + churn-adjusted forecast, weekly review log.</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {kpis.map((k) => (
          <div key={k.label} className="rounded-lg border p-3">
            <div className="text-xs text-gray-500">{k.label}</div>
            <div className="text-lg font-semibold">{k.value}</div>
          </div>
        ))}
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">ARR by Tier</h2>
        <DataTable columns={tierCols} rows={tiers} rowKey={(r: any) => r.amc_tier} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Growth Buckets</h2>
        <DataTable columns={growthCols} rows={growth} rowKey={(r: any) => r.period_label} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Hospitals by ARR</h2>
        <DataTable columns={hospitalCols} rows={topHospitals} rowKey={(r: any) => r.contract_id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Snapshots</h2>
        <DataTable columns={snapshotCols} rows={snapshots} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Weekly Reviews</h2>
        <DataTable columns={reviewCols} rows={reviews} rowKey={(r: any) => r.id} />
      </section>
    </div>
  );
}
