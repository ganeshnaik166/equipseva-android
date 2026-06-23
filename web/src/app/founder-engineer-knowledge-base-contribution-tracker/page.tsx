import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerKnowledgeBaseContributionTrackerPage() {
  const supabase = await getSupabaseServerClient();

  const [articles, recognition, topAuthors, monthlyTrend, kindBreakdown, recognitionPipeline, topViewed] = await Promise.all([
    supabase.rpc('list_articles_r2446'),
    supabase.rpc('list_recognition_r2446'),
    supabase.rpc('top_authors_r2446'),
    supabase.rpc('monthly_publishing_trend_r2446'),
    supabase.rpc('article_kind_breakdown_r2446'),
    supabase.rpc('recognition_pipeline_r2446'),
    supabase.rpc('top_viewed_articles_r2446'),
  ]);

  const fmtRupees = (n: number | null | undefined) =>
    n == null ? '-' : `Rs ${Number(n).toLocaleString('en-IN')}`;
  const fmtDate = (s: string | null | undefined) =>
    s ? new Date(s).toLocaleDateString('en-IN') : '-';
  const fmtDt = (s: string | null | undefined) =>
    s ? new Date(s).toLocaleString('en-IN') : '-';
  const fmtNum = (n: number | null | undefined) =>
    n == null ? '-' : Number(n).toLocaleString('en-IN');

  const statusBadge = (s: string) => {
    const map: Record<string, string> = {
      draft: 'bg-gray-100 text-gray-700',
      published: 'bg-blue-100 text-blue-800',
      featured: 'bg-purple-100 text-purple-800',
      retired: 'bg-yellow-100 text-yellow-800',
    };
    return (
      <span className={`px-2 py-0.5 rounded text-xs font-medium ${map[s] ?? 'bg-gray-100 text-gray-700'}`}>
        {s}
      </span>
    );
  };

  const recognitionBadge = (k: string) => {
    const map: Record<string, string> = {
      none: 'bg-gray-100 text-gray-700',
      spot_bonus: 'bg-blue-100 text-blue-800',
      monthly_award: 'bg-green-100 text-green-800',
      quarterly_award: 'bg-purple-100 text-purple-800',
    };
    return (
      <span className={`px-2 py-0.5 rounded text-xs font-medium ${map[k] ?? 'bg-gray-100 text-gray-700'}`}>
        {k}
      </span>
    );
  };

  const articlesCols: Column<any>[] = [
    { key: 'title', header: 'Title', render: (r: any) => r.title },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '-' },
    { key: 'equipment_kind', header: 'Equipment', render: (r: any) => r.equipment_kind },
    { key: 'article_kind', header: 'Kind', render: (r: any) => r.article_kind },
    { key: 'status', header: 'Status', render: (r: any) => statusBadge(r.status) },
    { key: 'view_count', header: 'Views', render: (r: any) => fmtNum(r.view_count) },
    { key: 'thumbs_up_count', header: 'Thumbs Up', render: (r: any) => fmtNum(r.thumbs_up_count) },
    { key: 'thumbs_down_count', header: 'Thumbs Down', render: (r: any) => fmtNum(r.thumbs_down_count) },
    { key: 'peer_reuse_count', header: 'Peer Reuse', render: (r: any) => fmtNum(r.peer_reuse_count) },
    { key: 'published_at', header: 'Published', render: (r: any) => fmtDt(r.published_at) },
  ];

  const recognitionCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '-' },
    { key: 'period_start', header: 'Period Start', render: (r: any) => fmtDate(r.period_start) },
    { key: 'period_end', header: 'Period End', render: (r: any) => fmtDate(r.period_end) },
    { key: 'articles_published', header: 'Articles', render: (r: any) => fmtNum(r.articles_published) },
    { key: 'total_views', header: 'Views', render: (r: any) => fmtNum(r.total_views) },
    { key: 'total_thumbs_up', header: 'Thumbs Up', render: (r: any) => fmtNum(r.total_thumbs_up) },
    { key: 'total_peer_reuse', header: 'Peer Reuse', render: (r: any) => fmtNum(r.total_peer_reuse) },
    { key: 'recognition_kind', header: 'Recognition', render: (r: any) => recognitionBadge(r.recognition_kind) },
    { key: 'bonus_rupees', header: 'Bonus', render: (r: any) => fmtRupees(r.bonus_rupees) },
    { key: 'awarded_at', header: 'Awarded', render: (r: any) => fmtDt(r.awarded_at) },
    { key: 'awarded_by_email', header: 'By', render: (r: any) => r.awarded_by_email ?? '-' },
  ];

  const topAuthorsCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '-' },
    { key: 'articles_count', header: 'Articles', render: (r: any) => fmtNum(r.articles_count) },
    { key: 'published_count', header: 'Published', render: (r: any) => fmtNum(r.published_count) },
    { key: 'featured_count', header: 'Featured', render: (r: any) => fmtNum(r.featured_count) },
    { key: 'total_views', header: 'Views', render: (r: any) => fmtNum(r.total_views) },
    { key: 'total_thumbs_up', header: 'Thumbs Up', render: (r: any) => fmtNum(r.total_thumbs_up) },
    { key: 'total_peer_reuse', header: 'Peer Reuse', render: (r: any) => fmtNum(r.total_peer_reuse) },
  ];

  const monthlyCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => fmtDate(r.month_start) },
    { key: 'articles_published', header: 'Articles', render: (r: any) => fmtNum(r.articles_published) },
    { key: 'total_views', header: 'Views', render: (r: any) => fmtNum(r.total_views) },
    { key: 'total_thumbs_up', header: 'Thumbs Up', render: (r: any) => fmtNum(r.total_thumbs_up) },
    { key: 'total_peer_reuse', header: 'Peer Reuse', render: (r: any) => fmtNum(r.total_peer_reuse) },
    { key: 'featured_count', header: 'Featured', render: (r: any) => fmtNum(r.featured_count) },
  ];

  const kindCols: Column<any>[] = [
    { key: 'article_kind', header: 'Kind', render: (r: any) => r.article_kind },
    { key: 'articles_count', header: 'Articles', render: (r: any) => fmtNum(r.articles_count) },
    { key: 'total_views', header: 'Views', render: (r: any) => fmtNum(r.total_views) },
    { key: 'total_thumbs_up', header: 'Thumbs Up', render: (r: any) => fmtNum(r.total_thumbs_up) },
    { key: 'total_thumbs_down', header: 'Thumbs Down', render: (r: any) => fmtNum(r.total_thumbs_down) },
    { key: 'total_peer_reuse', header: 'Peer Reuse', render: (r: any) => fmtNum(r.total_peer_reuse) },
    { key: 'avg_views', header: 'Avg Views', render: (r: any) => fmtNum(r.avg_views) },
  ];

  const pipelineCols: Column<any>[] = [
    { key: 'recognition_kind', header: 'Recognition', render: (r: any) => recognitionBadge(r.recognition_kind) },
    { key: 'awards_count', header: 'Awards', render: (r: any) => fmtNum(r.awards_count) },
    { key: 'total_bonus_rupees', header: 'Bonus Total', render: (r: any) => fmtRupees(r.total_bonus_rupees) },
    { key: 'total_articles', header: 'Articles', render: (r: any) => fmtNum(r.total_articles) },
    { key: 'total_views', header: 'Views', render: (r: any) => fmtNum(r.total_views) },
    { key: 'total_peer_reuse', header: 'Peer Reuse', render: (r: any) => fmtNum(r.total_peer_reuse) },
  ];

  const topViewedCols: Column<any>[] = [
    { key: 'title', header: 'Title', render: (r: any) => r.title },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '-' },
    { key: 'equipment_kind', header: 'Equipment', render: (r: any) => r.equipment_kind },
    { key: 'article_kind', header: 'Kind', render: (r: any) => r.article_kind },
    { key: 'status', header: 'Status', render: (r: any) => statusBadge(r.status) },
    { key: 'view_count', header: 'Views', render: (r: any) => fmtNum(r.view_count) },
    { key: 'thumbs_up_count', header: 'Thumbs Up', render: (r: any) => fmtNum(r.thumbs_up_count) },
    { key: 'peer_reuse_count', header: 'Peer Reuse', render: (r: any) => fmtNum(r.peer_reuse_count) },
    { key: 'published_at', header: 'Published', render: (r: any) => fmtDt(r.published_at) },
  ];

  return (
    <div className="p-6 space-y-8 max-w-7xl mx-auto">
      <header>
        <h1 className="text-3xl font-bold mb-2">Engineer Knowledge Base Contribution Tracker</h1>
        <p className="text-gray-600">
          KB articles authored & views & thumbs & peer-reuse & recognition pipeline
        </p>
      </header>

      <section>
        <h2 className="text-xl font-semibold mb-3">Top Authors</h2>
        <DataTable
          rows={topAuthors.data ?? []}
          columns={topAuthorsCols}
          emptyMessage="No authors yet"
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Top Viewed Articles</h2>
        <DataTable
          rows={topViewed.data ?? []}
          columns={topViewedCols}
          emptyMessage="No published articles yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Article Kind Breakdown</h2>
        <DataTable
          rows={kindBreakdown.data ?? []}
          columns={kindCols}
          emptyMessage="No article kinds yet"
          rowKey={(r: any, i: number) => String(r.article_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Monthly Publishing Trend</h2>
        <DataTable
          rows={monthlyTrend.data ?? []}
          columns={monthlyCols}
          emptyMessage="No monthly trend yet"
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Recognition Pipeline</h2>
        <DataTable
          rows={recognitionPipeline.data ?? []}
          columns={pipelineCols}
          emptyMessage="No recognition awarded yet"
          rowKey={(r: any, i: number) => String(r.recognition_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">All Articles</h2>
        <DataTable
          rows={articles.data ?? []}
          columns={articlesCols}
          emptyMessage="No articles logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-3">Recognition Awards</h2>
        <DataTable
          rows={recognition.data ?? []}
          columns={recognitionCols}
          emptyMessage="No recognition records"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
