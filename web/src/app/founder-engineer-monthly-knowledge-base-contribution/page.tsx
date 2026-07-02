import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_articles: number;
  total_views: number;
  total_kudos: number;
  total_saves: number;
  total_reward_rupees: number;
  featured_count: number;
  active_engineers: number;
};

type Article = {
  id: string;
  engineer_name: string;
  article_title: string;
  topic: string;
  device_brand: string;
  difficulty: string;
  view_count: number;
  kudos_count: number;
  resolution_saves: number;
  reward_rupees: number;
  status: string;
};

type TopicRow = {
  topic: string;
  rollup_month: string;
  total_articles: number;
  total_views: number;
  total_kudos: number;
  total_saves: number;
  reward_pool_rupees: number;
  demand_signal: string;
};

type LeaderRow = {
  engineer_name: string;
  article_count: number;
  total_views: number;
  total_kudos: number;
  total_saves: number;
  total_reward_rupees: number;
};

type DifficultyRow = {
  difficulty: string;
  article_count: number;
  avg_views: number;
  avg_kudos: number;
  total_reward: number;
};

type StatusRow = {
  status: string;
  article_count: number;
  total_views: number;
  total_reward: number;
};

type BrandRow = {
  device_brand: string;
  article_count: number;
  total_views: number;
  total_saves: number;
};

type GapRow = {
  topic: string;
  demand_signal: string;
  total_articles: number;
  total_views: number;
  gap_score: number;
};

function inr(n: number | null | undefined) {
  const v = Number(n ?? 0);
  return '₹' + v.toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, articlesRes, topicsRes, leadersRes, diffRes, statusRes, brandRes, gapsRes] = await Promise.all([
    supabase.rpc('founder_engineer_kb_kpi_r2754'),
    supabase.rpc('founder_engineer_kb_top_articles_r2754'),
    supabase.rpc('founder_engineer_kb_topic_rollup_r2754'),
    supabase.rpc('founder_engineer_kb_leaderboard_r2754'),
    supabase.rpc('founder_engineer_kb_difficulty_mix_r2754'),
    supabase.rpc('founder_engineer_kb_status_pipeline_r2754'),
    supabase.rpc('founder_engineer_kb_brand_coverage_r2754'),
    supabase.rpc('founder_engineer_kb_demand_gaps_r2754'),
  ]);

  const kpi: Kpi = (kpiRes.data?.[0] ?? {
    total_articles: 0,
    total_views: 0,
    total_kudos: 0,
    total_saves: 0,
    total_reward_rupees: 0,
    featured_count: 0,
    active_engineers: 0,
  }) as Kpi;

  const articles: Article[] = (articlesRes.data ?? []) as Article[];
  const topics: TopicRow[] = (topicsRes.data ?? []) as TopicRow[];
  const leaders: LeaderRow[] = (leadersRes.data ?? []) as LeaderRow[];
  const difficulties: DifficultyRow[] = (diffRes.data ?? []) as DifficultyRow[];
  const statuses: StatusRow[] = (statusRes.data ?? []) as StatusRow[];
  const brands: BrandRow[] = (brandRes.data ?? []) as BrandRow[];
  const gaps: GapRow[] = (gapsRes.data ?? []) as GapRow[];

  return (
    <main className="mx-auto max-w-7xl px-4 py-8 space-y-8">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Engineer Monthly Knowledge Base Contribution</h1>
        <p className="text-sm text-gray-600">
          Track engineer-authored KB articles, topic demand, kudos, resolution saves, and reward payouts.
          Articles where saves &gt;= 10 earn featured status.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <Kard label="Articles"        value={String(kpi.total_articles)} />
        <Kard label="Total Views"     value={Number(kpi.total_views).toLocaleString('en-IN')} />
        <Kard label="Total Kudos"     value={String(kpi.total_kudos)} />
        <Kard label="Resolution Saves" value={String(kpi.total_saves)} />
        <Kard label="Reward Paid"     value={inr(kpi.total_reward_rupees)} />
        <Kard label="Featured"        value={String(kpi.featured_count)} />
        <Kard label="Active Engineers" value={String(kpi.active_engineers)} />
        <Kard label="Avg Views / Article" value={kpi.total_articles ? Math.round(kpi.total_views / kpi.total_articles).toLocaleString('en-IN') : '0'} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Top Articles</h2>
        <DataTable
          rows={articles}
          columns={[
            { key: 'engineer_name',    header: 'Engineer',   render: (r: Article) => r.engineer_name },
            { key: 'article_title',    header: 'Title',      render: (r: Article) => r.article_title },
            { key: 'topic',            header: 'Topic',      render: (r: Article) => r.topic },
            { key: 'device_brand',     header: 'Brand',      render: (r: Article) => r.device_brand },
            { key: 'difficulty',       header: 'Level',      render: (r: Article) => r.difficulty },
            { key: 'view_count',       header: 'Views',      render: (r: Article) => r.view_count.toLocaleString('en-IN') },
            { key: 'kudos_count',      header: 'Kudos',      render: (r: Article) => String(r.kudos_count) },
            { key: 'resolution_saves', header: 'Saves',      render: (r: Article) => String(r.resolution_saves) },
            { key: 'reward_rupees',    header: 'Reward',     render: (r: Article) => inr(r.reward_rupees) },
            { key: 'status',           header: 'Status',     render: (r: Article) => r.status },
          ]}
          emptyMessage="No articles"
          rowKey={(r: Article, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Topic Rollup</h2>
        <DataTable
          rows={topics}
          columns={[
            { key: 'topic',              header: 'Topic',        render: (r: TopicRow) => r.topic },
            { key: 'total_articles',     header: 'Articles',     render: (r: TopicRow) => String(r.total_articles) },
            { key: 'total_views',        header: 'Views',        render: (r: TopicRow) => r.total_views.toLocaleString('en-IN') },
            { key: 'total_kudos',        header: 'Kudos',        render: (r: TopicRow) => String(r.total_kudos) },
            { key: 'total_saves',        header: 'Saves',        render: (r: TopicRow) => String(r.total_saves) },
            { key: 'reward_pool_rupees', header: 'Reward Pool',  render: (r: TopicRow) => inr(r.reward_pool_rupees) },
            { key: 'demand_signal',      header: 'Demand',       render: (r: TopicRow) => r.demand_signal },
          ]}
          emptyMessage="No topics"
          rowKey={(r: TopicRow, i: number) => String(r.topic + r.rollup_month + i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Engineer Leaderboard</h2>
        <DataTable
          rows={leaders}
          columns={[
            { key: 'engineer_name',       header: 'Engineer',     render: (r: LeaderRow) => r.engineer_name },
            { key: 'article_count',       header: 'Articles',     render: (r: LeaderRow) => String(r.article_count) },
            { key: 'total_views',         header: 'Views',        render: (r: LeaderRow) => Number(r.total_views).toLocaleString('en-IN') },
            { key: 'total_kudos',         header: 'Kudos',        render: (r: LeaderRow) => String(r.total_kudos) },
            { key: 'total_saves',         header: 'Saves',        render: (r: LeaderRow) => String(r.total_saves) },
            { key: 'total_reward_rupees', header: 'Reward Paid',  render: (r: LeaderRow) => inr(r.total_reward_rupees) },
          ]}
          emptyMessage="No engineers"
          rowKey={(r: LeaderRow, i: number) => String(r.engineer_name + i)}
        />
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="space-y-3">
          <h2 className="text-lg font-medium">Difficulty Mix</h2>
          <DataTable
            rows={difficulties}
            columns={[
              { key: 'difficulty',    header: 'Level',     render: (r: DifficultyRow) => r.difficulty },
              { key: 'article_count', header: 'Articles',  render: (r: DifficultyRow) => String(r.article_count) },
              { key: 'avg_views',     header: 'Avg Views', render: (r: DifficultyRow) => String(r.avg_views) },
              { key: 'avg_kudos',     header: 'Avg Kudos', render: (r: DifficultyRow) => String(r.avg_kudos) },
              { key: 'total_reward',  header: 'Reward',    render: (r: DifficultyRow) => inr(r.total_reward) },
            ]}
            emptyMessage="No data"
            rowKey={(r: DifficultyRow, i: number) => String(r.difficulty + i)}
          />
        </div>

        <div className="space-y-3">
          <h2 className="text-lg font-medium">Status Pipeline</h2>
          <DataTable
            rows={statuses}
            columns={[
              { key: 'status',        header: 'Status',    render: (r: StatusRow) => r.status },
              { key: 'article_count', header: 'Articles',  render: (r: StatusRow) => String(r.article_count) },
              { key: 'total_views',   header: 'Views',     render: (r: StatusRow) => Number(r.total_views).toLocaleString('en-IN') },
              { key: 'total_reward',  header: 'Reward',    render: (r: StatusRow) => inr(r.total_reward) },
            ]}
            emptyMessage="No data"
            rowKey={(r: StatusRow, i: number) => String(r.status + i)}
          />
        </div>
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="space-y-3">
          <h2 className="text-lg font-medium">Brand Coverage</h2>
          <DataTable
            rows={brands}
            columns={[
              { key: 'device_brand',  header: 'Brand',    render: (r: BrandRow) => r.device_brand },
              { key: 'article_count', header: 'Articles', render: (r: BrandRow) => String(r.article_count) },
              { key: 'total_views',   header: 'Views',    render: (r: BrandRow) => Number(r.total_views).toLocaleString('en-IN') },
              { key: 'total_saves',   header: 'Saves',    render: (r: BrandRow) => String(r.total_saves) },
            ]}
            emptyMessage="No data"
            rowKey={(r: BrandRow, i: number) => String(r.device_brand + i)}
          />
        </div>

        <div className="space-y-3">
          <h2 className="text-lg font-medium">High Demand Gaps</h2>
          <p className="text-xs text-gray-500">
            Topics with demand &gt;= high. Higher gap score =&gt; more views per article =&gt; opportunity to commission more authors.
          </p>
          <DataTable
            rows={gaps}
            columns={[
              { key: 'topic',          header: 'Topic',     render: (r: GapRow) => r.topic },
              { key: 'demand_signal',  header: 'Demand',    render: (r: GapRow) => r.demand_signal },
              { key: 'total_articles', header: 'Articles',  render: (r: GapRow) => String(r.total_articles) },
              { key: 'total_views',    header: 'Views',     render: (r: GapRow) => Number(r.total_views).toLocaleString('en-IN') },
              { key: 'gap_score',      header: 'Gap Score', render: (r: GapRow) => String(r.gap_score) },
            ]}
            emptyMessage="No gaps"
            rowKey={(r: GapRow, i: number) => String(r.topic + i)}
          />
        </div>
      </section>
    </main>
  );
}

function Kard({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
      <div className="text-xs uppercase tracking-wide text-gray-500">{label}</div>
      <div className="mt-1 text-xl font-semibold">{value}</div>
    </div>
  );
}
