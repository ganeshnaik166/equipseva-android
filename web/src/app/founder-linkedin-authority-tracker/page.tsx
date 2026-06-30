import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type PostPerformance = {
  post_topic: string;
  posts_count: number;
  total_impressions: number;
  avg_authority: number;
  total_dms: number;
  total_meetings: number;
  dm_to_meeting_pct: number;
};

type FormatRow = {
  post_format: string;
  posts: number;
  avg_impressions: number;
  avg_engagement_rate: number;
  avg_authority: number;
};

type CadenceRow = {
  week_start: string;
  posts: number;
  total_impressions: number;
  follower_delta: number;
  avg_authority: number;
};

type FunnelRow = {
  signal_type: string;
  signals: number;
  meetings_booked: number;
  converted: number;
  conversion_pct: number;
  total_value_rupees: number;
};

type SourceRow = {
  signal_source: string;
  signals: number;
  total_reach: number;
  authority_delta: number;
  meetings_converted: number;
};

type TopPostRow = {
  posted_at: string;
  post_topic: string;
  post_format: string;
  impressions: number;
  inbound_dms: number;
  dm_to_meeting_count: number;
  authority_score: number;
};

type InboundRow = {
  signal_at: string;
  signal_type: string;
  outlet_or_event: string;
  signal_source: string;
  meeting_outcome: string;
  meeting_value_rupees: number | null;
  notes: string | null;
};

type TrendRow = {
  period_week: string;
  avg_post_authority: number;
  signal_delta_sum: number;
  cumulative_score: number;
};

type PipelineRow = {
  bucket: string;
  signals: number;
  total_value_rupees: number;
};

function fmtNum(n: number | null | undefined): string {
  if (n == null) return '0';
  return new Intl.NumberFormat('en-IN').format(n);
}

function fmtINR(n: number | null | undefined): string {
  if (n == null) return '—';
  return '₹' + new Intl.NumberFormat('en-IN').format(n);
}

function fmtDate(s: string): string {
  return new Date(s).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    posts,
    formats,
    cadence,
    funnel,
    sources,
    topPosts,
    inbound,
    trend,
    pipeline,
  ] = await Promise.all([
    supabase.rpc('rpc_r3125_post_performance'),
    supabase.rpc('rpc_r3125_format_effectiveness'),
    supabase.rpc('rpc_r3125_weekly_cadence'),
    supabase.rpc('rpc_r3125_signal_funnel'),
    supabase.rpc('rpc_r3125_source_attribution'),
    supabase.rpc('rpc_r3125_top_posts'),
    supabase.rpc('rpc_r3125_inbound_queue'),
    supabase.rpc('rpc_r3125_authority_trend'),
    supabase.rpc('rpc_r3125_pipeline_value'),
  ]);

  const postRows: PostPerformance[] = (posts.data ?? []) as PostPerformance[];
  const formatRows: FormatRow[] = (formats.data ?? []) as FormatRow[];
  const cadenceRows: CadenceRow[] = (cadence.data ?? []) as CadenceRow[];
  const funnelRows: FunnelRow[] = (funnel.data ?? []) as FunnelRow[];
  const sourceRows: SourceRow[] = (sources.data ?? []) as SourceRow[];
  const topRows: TopPostRow[] = (topPosts.data ?? []) as TopPostRow[];
  const inboundRows: InboundRow[] = (inbound.data ?? []) as InboundRow[];
  const trendRows: TrendRow[] = (trend.data ?? []) as TrendRow[];
  const pipelineRows: PipelineRow[] = (pipeline.data ?? []) as PipelineRow[];

  const postCols: Column<PostPerformance>[] = [
    { key: 'post_topic', header: 'Topic', render: (r) => r.post_topic },
    { key: 'posts_count', header: 'Posts', render: (r) => fmtNum(r.posts_count) },
    { key: 'total_impressions', header: 'Impressions', render: (r) => fmtNum(r.total_impressions) },
    { key: 'avg_authority', header: 'Avg Authority', render: (r) => String(r.avg_authority) },
    { key: 'total_dms', header: 'DMs', render: (r) => fmtNum(r.total_dms) },
    { key: 'total_meetings', header: 'Meetings', render: (r) => fmtNum(r.total_meetings) },
    { key: 'dm_to_meeting_pct', header: 'DM to Meeting %', render: (r) => r.dm_to_meeting_pct + '%' },
  ];

  const formatCols: Column<FormatRow>[] = [
    { key: 'post_format', header: 'Format', render: (r) => r.post_format },
    { key: 'posts', header: 'Posts', render: (r) => fmtNum(r.posts) },
    { key: 'avg_impressions', header: 'Avg Impressions', render: (r) => fmtNum(r.avg_impressions) },
    { key: 'avg_engagement_rate', header: 'Engagement %', render: (r) => r.avg_engagement_rate + '%' },
    { key: 'avg_authority', header: 'Avg Authority', render: (r) => String(r.avg_authority) },
  ];

  const cadenceCols: Column<CadenceRow>[] = [
    { key: 'week_start', header: 'Week', render: (r) => r.week_start },
    { key: 'posts', header: 'Posts', render: (r) => fmtNum(r.posts) },
    { key: 'total_impressions', header: 'Impressions', render: (r) => fmtNum(r.total_impressions) },
    { key: 'follower_delta', header: 'Follower delta', render: (r) => fmtNum(r.follower_delta) },
    { key: 'avg_authority', header: 'Avg Authority', render: (r) => String(r.avg_authority) },
  ];

  const funnelCols: Column<FunnelRow>[] = [
    { key: 'signal_type', header: 'Signal type', render: (r) => r.signal_type },
    { key: 'signals', header: 'Signals', render: (r) => fmtNum(r.signals) },
    { key: 'meetings_booked', header: 'Meetings booked', render: (r) => fmtNum(r.meetings_booked) },
    { key: 'converted', header: 'Converted', render: (r) => fmtNum(r.converted) },
    { key: 'conversion_pct', header: 'Conversion %', render: (r) => r.conversion_pct + '%' },
    { key: 'total_value_rupees', header: 'Pipeline value', render: (r) => fmtINR(r.total_value_rupees) },
  ];

  const sourceCols: Column<SourceRow>[] = [
    { key: 'signal_source', header: 'Source', render: (r) => r.signal_source },
    { key: 'signals', header: 'Signals', render: (r) => fmtNum(r.signals) },
    { key: 'total_reach', header: 'Total reach', render: (r) => fmtNum(r.total_reach) },
    { key: 'authority_delta', header: 'Authority delta', render: (r) => String(r.authority_delta) },
    { key: 'meetings_converted', header: 'Meetings converted', render: (r) => fmtNum(r.meetings_converted) },
  ];

  const topCols: Column<TopPostRow>[] = [
    { key: 'posted_at', header: 'Posted', render: (r) => fmtDate(r.posted_at) },
    { key: 'post_topic', header: 'Topic', render: (r) => r.post_topic },
    { key: 'post_format', header: 'Format', render: (r) => r.post_format },
    { key: 'impressions', header: 'Impressions', render: (r) => fmtNum(r.impressions) },
    { key: 'inbound_dms', header: 'DMs', render: (r) => fmtNum(r.inbound_dms) },
    { key: 'dm_to_meeting_count', header: 'Meetings', render: (r) => fmtNum(r.dm_to_meeting_count) },
    { key: 'authority_score', header: 'Authority', render: (r) => String(r.authority_score) },
  ];

  const inboundCols: Column<InboundRow>[] = [
    { key: 'signal_at', header: 'When', render: (r) => fmtDate(r.signal_at) },
    { key: 'signal_type', header: 'Type', render: (r) => r.signal_type },
    { key: 'outlet_or_event', header: 'Outlet / Event', render: (r) => r.outlet_or_event },
    { key: 'signal_source', header: 'Source', render: (r) => r.signal_source },
    { key: 'meeting_outcome', header: 'Outcome', render: (r) => r.meeting_outcome },
    { key: 'meeting_value_rupees', header: 'Value', render: (r) => fmtINR(r.meeting_value_rupees) },
    { key: 'notes', header: 'Notes', render: (r) => r.notes ?? '—' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_week', header: 'Week', render: (r) => r.period_week },
    { key: 'avg_post_authority', header: 'Avg post authority', render: (r) => String(r.avg_post_authority) },
    { key: 'signal_delta_sum', header: 'Signal delta', render: (r) => String(r.signal_delta_sum) },
    { key: 'cumulative_score', header: 'Cumulative score', render: (r) => String(r.cumulative_score) },
  ];

  const pipelineCols: Column<PipelineRow>[] = [
    { key: 'bucket', header: 'Bucket', render: (r) => r.bucket },
    { key: 'signals', header: 'Signals', render: (r) => fmtNum(r.signals) },
    { key: 'total_value_rupees', header: 'Value', render: (r) => fmtINR(r.total_value_rupees) },
  ];

  return (
    <main className="mx-auto max-w-7xl space-y-10 p-6">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Founder LinkedIn Authority Tracker</h1>
        <p className="text-sm text-neutral-600">
          Personal brand telemetry: post cadence, impressions, inbound DMs, DM-to-meeting conversion,
          conference invites, media mentions and authority score trend.
        </p>
      </header>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Topic performance</h2>
        <DataTable
          rows={postRows}
          columns={postCols}
          emptyMessage="No posts yet"
          rowKey={(r, i) => String((r as PostPerformance).post_topic ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Format effectiveness</h2>
        <DataTable
          rows={formatRows}
          columns={formatCols}
          emptyMessage="No format data"
          rowKey={(r, i) => String((r as FormatRow).post_format ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Weekly cadence</h2>
        <DataTable
          rows={cadenceRows}
          columns={cadenceCols}
          emptyMessage="No cadence data"
          rowKey={(r, i) => String((r as CadenceRow).week_start ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Authority signal funnel</h2>
        <DataTable
          rows={funnelRows}
          columns={funnelCols}
          emptyMessage="No signals yet"
          rowKey={(r, i) => String((r as FunnelRow).signal_type ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Source attribution</h2>
        <DataTable
          rows={sourceRows}
          columns={sourceCols}
          emptyMessage="No source data"
          rowKey={(r, i) => String((r as SourceRow).signal_source ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Top performing posts</h2>
        <DataTable
          rows={topRows}
          columns={topCols}
          emptyMessage="No posts"
          rowKey={(r, i) => String((r as TopPostRow).posted_at ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">High-value inbound queue</h2>
        <DataTable
          rows={inboundRows}
          columns={inboundCols}
          emptyMessage="No inbound signals"
          rowKey={(r, i) => String((r as InboundRow).signal_at ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Authority score trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data"
          rowKey={(r, i) => String((r as TrendRow).period_week ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Pipeline value</h2>
        <DataTable
          rows={pipelineRows}
          columns={pipelineCols}
          emptyMessage="No pipeline data"
          rowKey={(r, i) => String((r as PipelineRow).bucket ?? i)}
        />
      </section>
    </main>
  );
}
