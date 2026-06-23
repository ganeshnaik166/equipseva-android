import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function HospitalChainMarketingCollateralUsagePage() {
  const supabase = await getSupabaseServerClient();

  const [usage, engagement, topRoi, channel, distribution, monthly, topChains] = await Promise.all([
    supabase.rpc('list_collateral_usage_r2507'),
    supabase.rpc('list_engagement_log_r2507'),
    supabase.rpc('top_roi_collateral_r2507'),
    supabase.rpc('channel_breakdown_r2507'),
    supabase.rpc('engagement_score_distribution_r2507'),
    supabase.rpc('monthly_usage_trend_r2507'),
    supabase.rpc('top_influencing_chains_r2507'),
  ]);

  const usageCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'collateral_kind', header: 'Collateral', render: (r: any) => r.collateral_kind },
    { key: 'channel', header: 'Channel', render: (r: any) => r.channel },
    { key: 'shared_at', header: 'Shared', render: (r: any) => new Date(r.shared_at).toLocaleDateString() },
    { key: 'engagement_score', header: 'Engagement', render: (r: any) => `${r.engagement_score}/100` },
    { key: 'deal_influence', header: 'Influence', render: (r: any) => r.deal_influence },
    { key: 'influenced_revenue_rupees', header: 'Revenue (Rs)', render: (r: any) => Number(r.influenced_revenue_rupees).toLocaleString('en-IN') },
    { key: 'roi_per_piece', header: 'ROI/piece', render: (r: any) => Number(r.roi_per_piece).toFixed(2) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
  ];

  const engagementCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'collateral_kind', header: 'Collateral', render: (r: any) => r.collateral_kind },
    { key: 'viewed_at', header: 'Viewed', render: (r: any) => new Date(r.viewed_at).toLocaleString() },
    { key: 'viewer_email', header: 'Viewer', render: (r: any) => r.viewer_email ?? '—' },
    { key: 'view_duration_seconds', header: 'Duration (s)', render: (r: any) => r.view_duration_seconds },
    { key: 'action_taken', header: 'Action', render: (r: any) => r.action_taken },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const roiCols: Column<any>[] = [
    { key: 'collateral_kind', header: 'Collateral', render: (r: any) => r.collateral_kind },
    { key: 'total_pieces', header: 'Pieces', render: (r: any) => r.total_pieces },
    { key: 'avg_roi', header: 'Avg ROI', render: (r: any) => Number(r.avg_roi).toFixed(2) },
    { key: 'total_influenced_revenue', header: 'Revenue (Rs)', render: (r: any) => Number(r.total_influenced_revenue).toLocaleString('en-IN') },
    { key: 'avg_engagement', header: 'Avg Engagement', render: (r: any) => Number(r.avg_engagement).toFixed(1) },
  ];

  const channelCols: Column<any>[] = [
    { key: 'channel', header: 'Channel', render: (r: any) => r.channel },
    { key: 'total_pieces', header: 'Pieces', render: (r: any) => r.total_pieces },
    { key: 'avg_engagement', header: 'Avg Engagement', render: (r: any) => Number(r.avg_engagement).toFixed(1) },
    { key: 'total_revenue', header: 'Revenue (Rs)', render: (r: any) => Number(r.total_revenue).toLocaleString('en-IN') },
  ];

  const distCols: Column<any>[] = [
    { key: 'bucket', header: 'Engagement Bucket', render: (r: any) => r.bucket },
    { key: 'count', header: 'Count', render: (r: any) => r.count },
  ];

  const monthlyCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'total_pieces', header: 'Pieces', render: (r: any) => r.total_pieces },
    { key: 'avg_engagement', header: 'Avg Engagement', render: (r: any) => Number(r.avg_engagement).toFixed(1) },
    { key: 'total_influenced_revenue', header: 'Revenue (Rs)', render: (r: any) => Number(r.total_influenced_revenue).toLocaleString('en-IN') },
  ];

  const chainCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'pieces_shared', header: 'Pieces', render: (r: any) => r.pieces_shared },
    { key: 'total_revenue', header: 'Revenue (Rs)', render: (r: any) => Number(r.total_revenue).toLocaleString('en-IN') },
    { key: 'avg_roi', header: 'Avg ROI', render: (r: any) => Number(r.avg_roi).toFixed(2) },
    { key: 'avg_engagement', header: 'Avg Engagement', render: (r: any) => Number(r.avg_engagement).toFixed(1) },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital Chain Marketing Collateral Usage</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Which case studies, decks & ROI calculators move the needle on chain deals — by channel, ROI & engagement.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top ROI by Collateral Kind</h2>
        <DataTable rows={topRoi.data ?? []} columns={roiCols} emptyMessage="No ROI data yet." rowKey={(r: any, i: number) => String(r.collateral_kind ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Channel Breakdown</h2>
        <DataTable rows={channel.data ?? []} columns={channelCols} emptyMessage="No channel data yet." rowKey={(r: any, i: number) => String(r.channel ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Engagement Score Distribution</h2>
        <DataTable rows={distribution.data ?? []} columns={distCols} emptyMessage="No engagement data yet." rowKey={(r: any, i: number) => String(r.bucket ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Monthly Usage Trend</h2>
        <DataTable rows={monthly.data ?? []} columns={monthlyCols} emptyMessage="No monthly data yet." rowKey={(r: any, i: number) => String(r.month_label ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top Influencing Chains</h2>
        <DataTable rows={topChains.data ?? []} columns={chainCols} emptyMessage="No chain data yet." rowKey={(r: any, i: number) => String(r.chain_name ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Collateral Usage Log</h2>
        <DataTable rows={usage.data ?? []} columns={usageCols} emptyMessage="No collateral shared yet." rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Engagement Log</h2>
        <DataTable rows={engagement.data ?? []} columns={engagementCols} emptyMessage="No engagement events yet." rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
