import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderQuarterlyContentPublishingCadencePage() {
  const supabase = await getSupabaseServerClient();

  const [plans, log, topReach, channelMix, actualVsPlanned, monthly, ownerLoad] = await Promise.all([
    supabase.rpc('list_plans_r2553'),
    supabase.rpc('list_publishing_log_r2553'),
    supabase.rpc('top_reach_posts_r2553'),
    supabase.rpc('channel_breakdown_r2553'),
    supabase.rpc('quarterly_actual_vs_planned_r2553'),
    supabase.rpc('monthly_publish_trend_r2553'),
    supabase.rpc('owner_load_r2553'),
  ]);

  const planCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'linkedin', header: 'LinkedIn (a/p)', render: (r: any) => `${r.linkedin_actual}/${r.linkedin_planned}` },
    { key: 'blog', header: 'Blog (a/p)', render: (r: any) => `${r.blog_actual}/${r.blog_planned}` },
    { key: 'podcast', header: 'Podcast (a/p)', render: (r: any) => `${r.podcast_actual}/${r.podcast_planned}` },
    { key: 'press', header: 'Press (a/p)', render: (r: any) => `${r.press_actual}/${r.press_planned}` },
    { key: 'total_reach', header: 'Total reach', render: (r: any) => (r.total_reach ?? 0).toLocaleString() },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const logCols: Column<any>[] = [
    { key: 'published_at', header: 'Published', render: (r: any) => new Date(r.published_at).toLocaleDateString() },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'channel_kind', header: 'Channel', render: (r: any) => r.channel_kind },
    { key: 'title', header: 'Title', render: (r: any) => r.title },
    { key: 'reach', header: 'Reach', render: (r: any) => (r.reach ?? 0).toLocaleString() },
    { key: 'engagement_score', header: 'Eng.', render: (r: any) => `${r.engagement_score}/100` },
    { key: 'top_takeaway', header: 'Takeaway', render: (r: any) => r.top_takeaway ?? '—' },
  ];

  const topCols: Column<any>[] = [
    { key: 'title', header: 'Title', render: (r: any) => r.title },
    { key: 'channel_kind', header: 'Channel', render: (r: any) => r.channel_kind },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'reach', header: 'Reach', render: (r: any) => (r.reach ?? 0).toLocaleString() },
    { key: 'engagement_score', header: 'Eng.', render: (r: any) => `${r.engagement_score}/100` },
    { key: 'published_at', header: 'Published', render: (r: any) => new Date(r.published_at).toLocaleDateString() },
  ];

  const channelCols: Column<any>[] = [
    { key: 'channel_kind', header: 'Channel', render: (r: any) => r.channel_kind },
    { key: 'post_count', header: 'Posts', render: (r: any) => r.post_count },
    { key: 'total_reach', header: 'Total reach', render: (r: any) => Number(r.total_reach ?? 0).toLocaleString() },
    { key: 'avg_engagement', header: 'Avg eng.', render: (r: any) => `${r.avg_engagement}/100` },
  ];

  const actualVsCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'channel_kind', header: 'Channel', render: (r: any) => r.channel_kind },
    { key: 'planned', header: 'Planned', render: (r: any) => r.planned },
    { key: 'actual', header: 'Actual', render: (r: any) => r.actual },
    { key: 'delta', header: 'Delta', render: (r: any) => (r.delta > 0 ? `+${r.delta}` : r.delta) },
  ];

  const monthlyCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'post_count', header: 'Posts', render: (r: any) => r.post_count },
    { key: 'total_reach', header: 'Reach', render: (r: any) => Number(r.total_reach ?? 0).toLocaleString() },
    { key: 'avg_engagement', header: 'Avg eng.', render: (r: any) => `${r.avg_engagement}/100` },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'plan_count', header: 'Plans', render: (r: any) => r.plan_count },
    { key: 'linkedin_actual_total', header: 'LinkedIn', render: (r: any) => r.linkedin_actual_total },
    { key: 'blog_actual_total', header: 'Blog', render: (r: any) => r.blog_actual_total },
    { key: 'podcast_actual_total', header: 'Podcast', render: (r: any) => r.podcast_actual_total },
    { key: 'press_actual_total', header: 'Press', render: (r: any) => r.press_actual_total },
    { key: 'reach_total', header: 'Reach', render: (r: any) => Number(r.reach_total ?? 0).toLocaleString() },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Founder — Quarterly Content Publishing Cadence</h1>
        <p className="text-sm text-gray-600 mt-1">Quarter × LinkedIn & blog & podcast & press — planned vs actual & reach.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarterly plans</h2>
        <DataTable
          rows={plans.data ?? []}
          columns={planCols}
          emptyMessage="No quarterly plans yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Actual vs planned</h2>
        <DataTable
          rows={actualVsPlanned.data ?? []}
          columns={actualVsCols}
          emptyMessage="No plan rows."
          rowKey={(r: any, i: number) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Publishing log</h2>
        <DataTable
          rows={log.data ?? []}
          columns={logCols}
          emptyMessage="No published items yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top reach posts</h2>
        <DataTable
          rows={topReach.data ?? []}
          columns={topCols}
          emptyMessage="No posts ranked."
          rowKey={(r: any, i: number) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Channel breakdown</h2>
        <DataTable
          rows={channelMix.data ?? []}
          columns={channelCols}
          emptyMessage="No channel data."
          rowKey={(r: any, i: number) => String(r.channel_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly publish trend</h2>
        <DataTable
          rows={monthly.data ?? []}
          columns={monthlyCols}
          emptyMessage="No monthly data."
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Owner load</h2>
        <DataTable
          rows={ownerLoad.data ?? []}
          columns={ownerCols}
          emptyMessage="No owners."
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>
    </main>
  );
}
