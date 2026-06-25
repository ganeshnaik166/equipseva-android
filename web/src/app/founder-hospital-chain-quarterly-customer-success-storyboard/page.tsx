import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function HospitalChainQuarterlyCustomerSuccessStoryboardPage() {
  const supabase = await getSupabaseServerClient();

  const [
    storiesRes,
    distLogRes,
    topReachRes,
    shareabilityRes,
    channelRes,
    quarterlyRes,
    funnelRes,
  ] = await Promise.all([
    supabase.rpc('list_stories_r2607'),
    supabase.rpc('list_distribution_log_r2607'),
    supabase.rpc('top_reach_stories_r2607'),
    supabase.rpc('shareability_distribution_r2607'),
    supabase.rpc('channel_kind_breakdown_r2607'),
    supabase.rpc('quarterly_story_trend_r2607'),
    supabase.rpc('status_funnel_r2607'),
  ]);

  const stories = (storiesRes.data ?? []) as any[];
  const distLog = (distLogRes.data ?? []) as any[];
  const topReach = (topReachRes.data ?? []) as any[];
  const shareability = (shareabilityRes.data ?? []) as any[];
  const channel = (channelRes.data ?? []) as any[];
  const quarterly = (quarterlyRes.data ?? []) as any[];
  const funnel = (funnelRes.data ?? []) as any[];

  const storyCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'story_title', header: 'Story', render: (r: any) => r.story_title },
    { key: 'shareability_kind', header: 'Shareability', render: (r: any) => r.shareability_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const logCols: Column<any>[] = [
    { key: 'story_title', header: 'Story', render: (r: any) => r.story_title ?? '-' },
    { key: 'distributed_at', header: 'Distributed', render: (r: any) => new Date(r.distributed_at).toLocaleDateString() },
    { key: 'channel_kind', header: 'Channel', render: (r: any) => r.channel_kind },
    { key: 'reach', header: 'Reach', render: (r: any) => Number(r.reach).toLocaleString() },
    { key: 'engagement_score', header: 'Engagement', render: (r: any) => `${r.engagement_score}/100` },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const topReachCols: Column<any>[] = [
    { key: 'story_title', header: 'Story', render: (r: any) => r.story_title },
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'total_reach', header: 'Total Reach', render: (r: any) => Number(r.total_reach).toLocaleString() },
    { key: 'avg_engagement', header: 'Avg Engagement', render: (r: any) => `${r.avg_engagement}/100` },
    { key: 'distribution_count', header: 'Distributions', render: (r: any) => r.distribution_count },
  ];

  const shareabilityCols: Column<any>[] = [
    { key: 'shareability_kind', header: 'Shareability', render: (r: any) => r.shareability_kind },
    { key: 'story_count', header: 'Stories', render: (r: any) => r.story_count },
    { key: 'pct', header: 'Share %', render: (r: any) => `${r.pct}%` },
  ];

  const channelCols: Column<any>[] = [
    { key: 'channel_kind', header: 'Channel', render: (r: any) => r.channel_kind },
    { key: 'log_count', header: 'Distributions', render: (r: any) => r.log_count },
    { key: 'total_reach', header: 'Total Reach', render: (r: any) => Number(r.total_reach).toLocaleString() },
    { key: 'avg_engagement', header: 'Avg Engagement', render: (r: any) => `${r.avg_engagement}/100` },
  ];

  const quarterlyCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'story_count', header: 'Stories', render: (r: any) => r.story_count },
    { key: 'published_count', header: 'Published', render: (r: any) => r.published_count },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'story_count', header: 'Stories', render: (r: any) => r.story_count },
    { key: 'pct', header: 'Share %', render: (r: any) => `${r.pct}%` },
  ];

  return (
    <div style={{ padding: '2rem', maxWidth: '1400px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.875rem', fontWeight: 700, marginBottom: '0.5rem' }}>
        Hospital Chain Quarterly Customer Success Storyboard
      </h1>
      <p style={{ color: '#666', marginBottom: '2rem' }}>
        Track quarterly success stories from hospital chains & distribution reach across channels => case studies, conferences & sales decks.
      </p>

      <section style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Success Stories</h2>
        <DataTable
          rows={stories}
          columns={storyCols}
          emptyMessage="No success stories yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Top Reach Stories</h2>
        <DataTable
          rows={topReach}
          columns={topReachCols}
          emptyMessage="No reach data yet."
          rowKey={(r: any, i: number) => String(r.story_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Distribution Log</h2>
        <DataTable
          rows={distLog}
          columns={logCols}
          emptyMessage="No distributions logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Shareability Distribution</h2>
        <DataTable
          rows={shareability}
          columns={shareabilityCols}
          emptyMessage="No shareability data."
          rowKey={(r: any, i: number) => String(r.shareability_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Channel Kind Breakdown</h2>
        <DataTable
          rows={channel}
          columns={channelCols}
          emptyMessage="No channel data."
          rowKey={(r: any, i: number) => String(r.channel_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Quarterly Story Trend</h2>
        <DataTable
          rows={quarterly}
          columns={quarterlyCols}
          emptyMessage="No quarterly data."
          rowKey={(r: any, i: number) => String(r.quarter_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Status Funnel</h2>
        <DataTable
          rows={funnel}
          columns={funnelCols}
          emptyMessage="No status data."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>
    </div>
  );
}
