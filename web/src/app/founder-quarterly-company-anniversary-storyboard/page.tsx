import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, byYearRes, byQuarterRes, byCategoryRes, byFormatRes, byChannelRes, topStoriesRes, milestonesRes] = await Promise.all([
    supabase.rpc('r2805_kpis'),
    supabase.rpc('r2805_milestones_by_year'),
    supabase.rpc('r2805_milestones_by_quarter'),
    supabase.rpc('r2805_milestones_by_category'),
    supabase.rpc('r2805_stories_by_format'),
    supabase.rpc('r2805_stories_by_channel'),
    supabase.rpc('r2805_top_stories'),
    supabase.rpc('r2805_milestones_full'),
  ]);

  const kpis = (kpisRes.data as Array<Record<string, unknown>> | null)?.[0] ?? {};
  const byYear = (byYearRes.data as Array<Record<string, unknown>> | null) ?? [];
  const byQuarter = (byQuarterRes.data as Array<Record<string, unknown>> | null) ?? [];
  const byCategory = (byCategoryRes.data as Array<Record<string, unknown>> | null) ?? [];
  const byFormat = (byFormatRes.data as Array<Record<string, unknown>> | null) ?? [];
  const byChannel = (byChannelRes.data as Array<Record<string, unknown>> | null) ?? [];
  const topStories = (topStoriesRes.data as Array<Record<string, unknown>> | null) ?? [];
  const milestones = (milestonesRes.data as Array<Record<string, unknown>> | null) ?? [];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Quarterly Company Anniversary Storyboard</h1>
        <p className="text-sm text-gray-600">Year × milestone × story × audience × distribution × engagement × tag.</p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-6 gap-3">
        <Kpi label="Milestones" value={String(kpis.total_milestones ?? 0)} />
        <Kpi label="Published" value={String(kpis.published_milestones ?? 0)} />
        <Kpi label="Stories" value={String(kpis.total_stories ?? 0)} />
        <Kpi label="Views" value={String(kpis.total_views ?? 0)} />
        <Kpi label="Shares" value={String(kpis.total_shares ?? 0)} />
        <Kpi label="Avg Engagement" value={String(kpis.avg_engagement ?? 0)} />
      </div>

      <Section title="Milestones by year">
        <DataTable
          rows={byYear}
          columns={[
            { key: 'anniversary_year', header: 'Year', render: (r) => String(r.anniversary_year) },
            { key: 'milestone_count', header: 'Milestones', render: (r) => String(r.milestone_count) },
            { key: 'published_count', header: 'Published', render: (r) => String(r.published_count) },
            { key: 'avg_engagement', header: 'Avg Engagement', render: (r) => String(r.avg_engagement) },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.anniversary_year ?? i)}
        />
      </Section>

      <Section title="Milestones by quarter">
        <DataTable
          rows={byQuarter}
          columns={[
            { key: 'quarter', header: 'Quarter', render: (r) => String(r.quarter) },
            { key: 'milestone_count', header: 'Count', render: (r) => String(r.milestone_count) },
            { key: 'avg_engagement', header: 'Avg Engagement', render: (r) => String(r.avg_engagement) },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.quarter ?? i)}
        />
      </Section>

      <Section title="Milestones by category">
        <DataTable
          rows={byCategory}
          columns={[
            { key: 'milestone_category', header: 'Category', render: (r) => String(r.milestone_category) },
            { key: 'milestone_count', header: 'Milestones', render: (r) => String(r.milestone_count) },
            { key: 'total_metric_count', header: 'Total metric count', render: (r) => String(r.total_metric_count) },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.milestone_category ?? i)}
        />
      </Section>

      <Section title="Stories by format">
        <DataTable
          rows={byFormat}
          columns={[
            { key: 'story_format', header: 'Format', render: (r) => String(r.story_format) },
            { key: 'story_count', header: 'Stories', render: (r) => String(r.story_count) },
            { key: 'total_views', header: 'Views', render: (r) => String(r.total_views) },
            { key: 'total_shares', header: 'Shares', render: (r) => String(r.total_shares) },
            { key: 'avg_engagement', header: 'Avg Engagement', render: (r) => String(r.avg_engagement) },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.story_format ?? i)}
        />
      </Section>

      <Section title="Stories by distribution channel">
        <DataTable
          rows={byChannel}
          columns={[
            { key: 'distribution_channel', header: 'Channel', render: (r) => String(r.distribution_channel) },
            { key: 'story_count', header: 'Stories', render: (r) => String(r.story_count) },
            { key: 'total_views', header: 'Views', render: (r) => String(r.total_views) },
            { key: 'total_reactions', header: 'Reactions', render: (r) => String(r.total_reactions) },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.distribution_channel ?? i)}
        />
      </Section>

      <Section title="Top stories (engagement-ranked)">
        <DataTable
          rows={topStories}
          columns={[
            { key: 'story_title', header: 'Title', render: (r) => String(r.story_title) },
            { key: 'storyteller_name', header: 'Storyteller', render: (r) => String(r.storyteller_name) },
            { key: 'story_format', header: 'Format', render: (r) => String(r.story_format) },
            { key: 'views', header: 'Views', render: (r) => String(r.views) },
            { key: 'shares', header: 'Shares', render: (r) => String(r.shares) },
            { key: 'engagement_score', header: 'Engagement', render: (r) => String(r.engagement_score) },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.story_title ?? i)}
        />
      </Section>

      <Section title="All milestones">
        <DataTable
          rows={milestones}
          columns={[
            { key: 'milestone_title', header: 'Title', render: (r) => String(r.milestone_title) },
            { key: 'anniversary_year', header: 'Year', render: (r) => String(r.anniversary_year) },
            { key: 'quarter', header: 'Quarter', render: (r) => String(r.quarter) },
            { key: 'milestone_category', header: 'Category', render: (r) => String(r.milestone_category) },
            { key: 'audience', header: 'Audience', render: (r) => String(r.audience) },
            { key: 'distribution_channel', header: 'Channel', render: (r) => String(r.distribution_channel) },
            { key: 'engagement_score', header: 'Engagement', render: (r) => String(r.engagement_score) },
            { key: 'tag', header: 'Tag', render: (r) => String(r.tag) },
            { key: 'is_published', header: 'Published', render: (r) => (r.is_published ? 'yes' : 'no') },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.milestone_title ?? i)}
        />
      </Section>
    </div>
  );
}

function Kpi({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded border p-3 bg-white">
      <div className="text-xs text-gray-500">{label}</div>
      <div className="text-xl font-semibold">{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="space-y-2">
      <h2 className="text-lg font-semibold">{title}</h2>
      {children}
    </section>
  );
}
