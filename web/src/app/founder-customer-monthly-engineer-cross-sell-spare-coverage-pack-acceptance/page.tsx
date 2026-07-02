import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import type { Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type FunnelRow = { stage: string; event_count: number; pct_of_views: number };
type TierRow = { pack_tier: string; total_contract_rupees: number; total_commission_rupees: number; accept_count: number };
type RegionRow = { region: string; offers_count: number; accepts_count: number; acceptance_rate_pct: number };
type DeviceRow = { device_category: string; offers_count: number; avg_price_rupees: number; total_spare_units: number };
type TrendRow = { day_bucket: string; accept_count: number; contract_revenue: number };
type ExpiringRow = { pack_name: string; pack_tier: string; region: string; expires_at: string; hours_remaining: number };
type ChurnRow = { metric: string; value_text: string };
type EnterpriseRow = { pack_name: string; region: string; device_category: string; monthly_price_rupees: number; status: string; offered_at: string };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [funnelRes, tierRes, regionRes, deviceRes, trendRes, expiringRes, churnRes, enterpriseRes] = await Promise.all([
    supabase.rpc('rpc_r2932_acceptance_funnel'),
    supabase.rpc('rpc_r2932_revenue_by_tier'),
    supabase.rpc('rpc_r2932_regional_heatmap'),
    supabase.rpc('rpc_r2932_top_device_categories'),
    supabase.rpc('rpc_r2932_daily_trend'),
    supabase.rpc('rpc_r2932_expiring_offers'),
    supabase.rpc('rpc_r2932_churn_summary'),
    supabase.rpc('rpc_r2932_enterprise_pipeline'),
  ]);

  const funnel: FunnelRow[] = (funnelRes.data as FunnelRow[]) ?? [];
  const tiers: TierRow[] = (tierRes.data as TierRow[]) ?? [];
  const regions: RegionRow[] = (regionRes.data as RegionRow[]) ?? [];
  const devices: DeviceRow[] = (deviceRes.data as DeviceRow[]) ?? [];
  const trend: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const expiring: ExpiringRow[] = (expiringRes.data as ExpiringRow[]) ?? [];
  const churn: ChurnRow[] = (churnRes.data as ChurnRow[]) ?? [];
  const enterprise: EnterpriseRow[] = (enterpriseRes.data as EnterpriseRow[]) ?? [];

  const funnelCols: Column<FunnelRow>[] = [
    { key: 'stage', header: 'Stage', render: (r) => r.stage },
    { key: 'event_count', header: 'Events', render: (r) => r.event_count },
    { key: 'pct_of_views', header: '% of Views', render: (r) => `${r.pct_of_views}%` },
  ];

  const tierCols: Column<TierRow>[] = [
    { key: 'pack_tier', header: 'Tier', render: (r) => r.pack_tier },
    { key: 'total_contract_rupees', header: 'Contract Value (₹)', render: (r) => r.total_contract_rupees?.toLocaleString() ?? '0' },
    { key: 'total_commission_rupees', header: 'Engineer Commission (₹)', render: (r) => r.total_commission_rupees?.toLocaleString() ?? '0' },
    { key: 'accept_count', header: 'Accepts', render: (r) => r.accept_count },
  ];

  const regionCols: Column<RegionRow>[] = [
    { key: 'region', header: 'Region', render: (r) => r.region },
    { key: 'offers_count', header: 'Offers', render: (r) => r.offers_count },
    { key: 'accepts_count', header: 'Accepts', render: (r) => r.accepts_count },
    { key: 'acceptance_rate_pct', header: 'Accept Rate', render: (r) => `${r.acceptance_rate_pct}%` },
  ];

  const deviceCols: Column<DeviceRow>[] = [
    { key: 'device_category', header: 'Device Category', render: (r) => r.device_category },
    { key: 'offers_count', header: 'Offers', render: (r) => r.offers_count },
    { key: 'avg_price_rupees', header: 'Avg Price (₹)', render: (r) => r.avg_price_rupees?.toLocaleString() ?? '0' },
    { key: 'total_spare_units', header: 'Total Spare Units', render: (r) => r.total_spare_units },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'day_bucket', header: 'Day', render: (r) => r.day_bucket },
    { key: 'accept_count', header: 'Accepts', render: (r) => r.accept_count },
    { key: 'contract_revenue', header: 'Revenue (₹)', render: (r) => r.contract_revenue?.toLocaleString() ?? '0' },
  ];

  const expiringCols: Column<ExpiringRow>[] = [
    { key: 'pack_name', header: 'Pack', render: (r) => r.pack_name },
    { key: 'pack_tier', header: 'Tier', render: (r) => r.pack_tier },
    { key: 'region', header: 'Region', render: (r) => r.region },
    { key: 'expires_at', header: 'Expires', render: (r) => new Date(r.expires_at).toLocaleString() },
    { key: 'hours_remaining', header: 'Hours Left', render: (r) => r.hours_remaining },
  ];

  const churnCols: Column<ChurnRow>[] = [
    { key: 'metric', header: 'Metric', render: (r) => r.metric },
    { key: 'value_text', header: 'Value', render: (r) => r.value_text },
  ];

  const enterpriseCols: Column<EnterpriseRow>[] = [
    { key: 'pack_name', header: 'Pack', render: (r) => r.pack_name },
    { key: 'region', header: 'Region', render: (r) => r.region },
    { key: 'device_category', header: 'Device', render: (r) => r.device_category },
    { key: 'monthly_price_rupees', header: 'Monthly Price (₹)', render: (r) => r.monthly_price_rupees?.toLocaleString() ?? '0' },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'offered_at', header: 'Offered', render: (r) => new Date(r.offered_at).toLocaleDateString() },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Customer Monthly Engineer Cross-Sell — Spare Coverage Pack Acceptance</h1>
        <p className="text-sm text-gray-600 mt-1">Round r2932 · 1500/50 milestone batch · HEAVY</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Acceptance Funnel</h2>
        <DataTable rows={funnel} columns={funnelCols} emptyMessage="No funnel data" rowKey={(r, i) => String(r.stage ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Revenue by Pack Tier</h2>
        <DataTable rows={tiers} columns={tierCols} emptyMessage="No tier data" rowKey={(r, i) => String(r.pack_tier ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Regional Acceptance Heatmap</h2>
        <DataTable rows={regions} columns={regionCols} emptyMessage="No regional data" rowKey={(r, i) => String(r.region ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Device Categories</h2>
        <DataTable rows={devices} columns={deviceCols} emptyMessage="No device data" rowKey={(r, i) => String(r.device_category ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Daily Acceptance Trend (last 30 days)</h2>
        <DataTable rows={trend} columns={trendCols} emptyMessage="No trend data" rowKey={(r, i) => String(r.day_bucket ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Expiring Offers — Urgency Queue</h2>
        <DataTable rows={expiring} columns={expiringCols} emptyMessage="No expiring offers" rowKey={(r, i) => String(r.pack_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Churn & Retention Summary</h2>
        <DataTable rows={churn} columns={churnCols} emptyMessage="No churn data" rowKey={(r, i) => String(r.metric ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Enterprise & Premium Pipeline</h2>
        <DataTable rows={enterprise} columns={enterpriseCols} emptyMessage="No enterprise offers" rowKey={(r, i) => String(r.pack_name ?? i)} />
      </section>
    </main>
  );
}
