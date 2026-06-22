import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Overview = {
  total_customers_tracked: number;
  rising_count: number;
  stable_count: number;
  declining_count: number;
  dormant_count: number;
  avg_stickiness_score: number;
  flagged_for_outreach: number;
  campaigns_last_30d: number;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [
    { data: overviewArr },
    { data: declining },
    { data: weekly },
    { data: campaigns },
    { data: effectiveness },
  ] = await Promise.all([
    sb.rpc('r2264_stickiness_overview'),
    sb.rpc('r2264_top_declining_customers', { p_limit: 25 }),
    sb.rpc('r2264_weekly_aggregate', { p_weeks: 12 }),
    sb.rpc('r2264_recent_campaigns', { p_limit: 25 }),
    sb.rpc('r2264_campaign_effectiveness'),
  ]);

  const overview: Overview = (overviewArr?.[0] ?? {
    total_customers_tracked: 0,
    rising_count: 0,
    stable_count: 0,
    declining_count: 0,
    dormant_count: 0,
    avg_stickiness_score: 0,
    flagged_for_outreach: 0,
    campaigns_last_30d: 0,
  }) as Overview;

  const decliningCols: Column<any>[] = [
    { key: 'customer_email', header: 'Customer', render: (r) => r.customer_email ?? '—' },
    { key: 'latest_week', header: 'Latest Week', render: (r) => r.latest_week ?? '—' },
    { key: 'latest_score', header: 'Score (0-100)', render: (r) => Number(r.latest_score ?? 0).toFixed(1) },
    { key: 'trend', header: 'Trend', render: (r) => r.trend ?? '—' },
    { key: 'total_events', header: 'Events', render: (r) => r.total_events ?? 0 },
    { key: 'weeks_declining', header: 'Weeks Declining', render: (r) => r.weeks_declining ?? 0 },
  ];

  const weeklyCols: Column<any>[] = [
    { key: 'week_start', header: 'Week Start', render: (r) => r.week_start ?? '—' },
    { key: 'customers_active', header: 'Active Customers', render: (r) => r.customers_active ?? 0 },
    { key: 'total_events', header: 'Total Events', render: (r) => r.total_events ?? 0 },
    { key: 'avg_score', header: 'Avg Score', render: (r) => Number(r.avg_score ?? 0).toFixed(1) },
    { key: 'declining_pct', header: 'Declining %', render: (r) => `${Number(r.declining_pct ?? 0).toFixed(1)}%` },
  ];

  const campaignCols: Column<any>[] = [
    { key: 'customer_email', header: 'Customer', render: (r) => r.customer_email ?? '—' },
    { key: 'campaign_type', header: 'Channel', render: (r) => r.campaign_type ?? '—' },
    { key: 'campaign_name', header: 'Campaign', render: (r) => r.campaign_name ?? '—' },
    { key: 'sent_at', header: 'Sent', render: (r) => r.sent_at ? new Date(r.sent_at).toLocaleString() : '—' },
    { key: 'status', header: 'Status', render: (r) => r.status ?? '—' },
    { key: 'outcome', header: 'Outcome', render: (r) => r.outcome ?? 'pending' },
  ];

  const effectivenessCols: Column<any>[] = [
    { key: 'campaign_type', header: 'Channel', render: (r) => r.campaign_type ?? '—' },
    { key: 'sent_count', header: 'Sent', render: (r) => r.sent_count ?? 0 },
    { key: 'reactivated_count', header: 'Reactivated', render: (r) => r.reactivated_count ?? 0 },
    { key: 'no_change_count', header: 'No Change', render: (r) => r.no_change_count ?? 0 },
    { key: 'churned_count', header: 'Churned', render: (r) => r.churned_count ?? 0 },
    { key: 'reactivation_rate', header: 'Reactivation Rate', render: (r) => `${Number(r.reactivation_rate ?? 0).toFixed(1)}%` },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '26px', fontWeight: 700, marginBottom: '8px' }}>
        Customer Activity Stickiness Index
      </h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Weekly logins &amp; usage events per customer. Flags declining usage (score &lt; 50) &amp; tracks re-engagement campaigns.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px', marginBottom: '28px' }}>
        <Stat label="Customers Tracked" value={overview.total_customers_tracked} />
        <Stat label="Rising" value={overview.rising_count} accent="#16a34a" />
        <Stat label="Stable" value={overview.stable_count} accent="#0284c7" />
        <Stat label="Declining" value={overview.declining_count} accent="#f59e0b" />
        <Stat label="Dormant" value={overview.dormant_count} accent="#dc2626" />
        <Stat label="Avg Score" value={Number(overview.avg_stickiness_score ?? 0).toFixed(1)} />
        <Stat label="Flagged for Outreach" value={overview.flagged_for_outreach} accent="#dc2626" />
        <Stat label="Campaigns (last 30d)" value={overview.campaigns_last_30d} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>
          Top Declining Customers (score &lt; 50 or trending dormant)
        </h2>
        <DataTable columns={decliningCols} rows={declining ?? []} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>
          Weekly Aggregate (last 12 weeks)
        </h2>
        <DataTable columns={weeklyCols} rows={weekly ?? []} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>
          Recent Re-engagement Campaigns
        </h2>
        <DataTable columns={campaignCols} rows={campaigns ?? []} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>
          Campaign Effectiveness by Channel
        </h2>
        <DataTable columns={effectivenessCols} rows={effectiveness ?? []} rowKey={(_, i) => String(i)} />
      </section>
    </div>
  );
}

function Stat({ label, value, accent }: { label: string; value: number | string; accent?: string }) {
  return (
    <div style={{
      background: '#fff',
      border: '1px solid #e5e7eb',
      borderRadius: '10px',
      padding: '14px 16px',
      boxShadow: '0 1px 2px rgba(0,0,0,0.04)',
    }}>
      <div style={{ fontSize: '12px', color: '#6b7280', textTransform: 'uppercase', letterSpacing: '0.04em' }}>
        {label}
      </div>
      <div style={{ fontSize: '24px', fontWeight: 700, color: accent ?? '#111827', marginTop: '4px' }}>
        {value}
      </div>
    </div>
  );
}