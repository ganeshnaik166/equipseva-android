import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Article = {
  id: string;
  title: string;
  category: string;
  status: string;
  author_email: string | null;
  published_at: string | null;
  view_count: number;
  last_reviewed_at: string | null;
  created_at: string;
};

type ViewRow = {
  id: string;
  article_id: string;
  article_title: string;
  viewer_email: string | null;
  viewed_at: string;
  search_query: string | null;
};

type TopRow = {
  id: string;
  title: string;
  category: string;
  view_count: number;
  published_at: string | null;
};

type StaleRow = {
  id: string;
  title: string;
  category: string;
  last_reviewed_at: string | null;
  published_at: string | null;
  days_since_review: number;
};

function fmt(ts: string | null) {
  if (!ts) return '-';
  try {
    return new Date(ts).toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' });
  } catch {
    return ts;
  }
}

export default async function FounderKnowledgeBasePage() {
  const sb = await getSupabaseServerClient();

  const [articlesRes, viewsRes, topRes, staleRes] = await Promise.all([
    sb.rpc('fkb_list_articles_r1742', { p_status: null, p_category: null }),
    sb.rpc('fkb_list_views_r1742', { p_article_id: null, p_limit: 50 }),
    sb.rpc('fkb_top_viewed_r1742', { p_limit: 20 }),
    sb.rpc('fkb_stale_articles_r1742', { p_days: 90 }),
  ]);

  const articles: Article[] = Array.isArray(articlesRes.data) ? (articlesRes.data as Article[]) : [];
  const views: ViewRow[] = Array.isArray(viewsRes.data) ? (viewsRes.data as ViewRow[]) : [];
  const top: TopRow[] = Array.isArray(topRes.data) ? (topRes.data as TopRow[]) : [];
  const stale: StaleRow[] = Array.isArray(staleRes.data) ? (staleRes.data as StaleRow[]) : [];

  const published = articles.filter((a) => a.status === 'published').length;
  const drafts = articles.filter((a) => a.status === 'draft').length;
  const archived = articles.filter((a) => a.status === 'archived').length;
  const totalViews = articles.reduce((s, a) => s + (a.view_count || 0), 0);

  const articleCols: Column<Article>[] = [
    { key: 'title', header: 'Title', render: (r: any) => <span className="font-medium">{r.title}</span> },
    { key: 'category', header: 'Category', render: (r: any) => <span className="text-xs uppercase">{r.category}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="text-xs">{r.status}</span> },
    { key: 'author_email', header: 'Author', render: (r: any) => <span className="text-xs">{r.author_email ?? '-'}</span> },
    { key: 'view_count', header: 'Views', render: (r: any) => <span className="tabular-nums">{r.view_count ?? 0}</span> },
    { key: 'published_at', header: 'Published', render: (r: any) => <span className="text-xs">{fmt(r.published_at)}</span> },
    { key: 'last_reviewed_at', header: 'Last Reviewed', render: (r: any) => <span className="text-xs">{fmt(r.last_reviewed_at)}</span> },
  ];

  const viewCols: Column<ViewRow>[] = [
    { key: 'viewed_at', header: 'When', render: (r: any) => <span className="text-xs">{fmt(r.viewed_at)}</span> },
    { key: 'article_title', header: 'Article', render: (r: any) => <span>{r.article_title}</span> },
    { key: 'viewer_email', header: 'Viewer', render: (r: any) => <span className="text-xs">{r.viewer_email ?? '-'}</span> },
    { key: 'search_query', header: 'Search', render: (r: any) => <span className="text-xs">{r.search_query ?? '-'}</span> },
  ];

  const topCols: Column<TopRow>[] = [
    { key: 'title', header: 'Title', render: (r: any) => <span className="font-medium">{r.title}</span> },
    { key: 'category', header: 'Category', render: (r: any) => <span className="text-xs uppercase">{r.category}</span> },
    { key: 'view_count', header: 'Views', render: (r: any) => <span className="tabular-nums font-semibold">{r.view_count ?? 0}</span> },
    { key: 'published_at', header: 'Published', render: (r: any) => <span className="text-xs">{fmt(r.published_at)}</span> },
  ];

  const staleCols: Column<StaleRow>[] = [
    { key: 'title', header: 'Title', render: (r: any) => <span className="font-medium">{r.title}</span> },
    { key: 'category', header: 'Category', render: (r: any) => <span className="text-xs uppercase">{r.category}</span> },
    { key: 'days_since_review', header: 'Days Stale', render: (r: any) => <span className="tabular-nums font-semibold text-amber-700">{r.days_since_review ?? 0}</span> },
    { key: 'last_reviewed_at', header: 'Last Reviewed', render: (r: any) => <span className="text-xs">{fmt(r.last_reviewed_at)}</span> },
    { key: 'published_at', header: 'Published', render: (r: any) => <span className="text-xs">{fmt(r.published_at)}</span> },
  ];

  return (
    <div className="mx-auto max-w-7xl p-6 space-y-8">
      <header className="space-y-2">
        <h1 className="text-2xl font-bold">Founder Knowledge Base</h1>
        <p className="text-sm text-gray-600">
          Internal founder wiki — how-tos, decisions, playbooks, policies, SOPs. Articles older than 90 days are flagged for review.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs text-gray-500">Published</div>
          <div className="text-2xl font-bold tabular-nums">{published}</div>
        </div>
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs text-gray-500">Drafts</div>
          <div className="text-2xl font-bold tabular-nums">{drafts}</div>
        </div>
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs text-gray-500">Archived</div>
          <div className="text-2xl font-bold tabular-nums">{archived}</div>
        </div>
        <div className="rounded-lg border bg-white p-4">
          <div className="text-xs text-gray-500">Total Views</div>
          <div className="text-2xl font-bold tabular-nums">{totalViews}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">All Articles</h2>
        <p className="text-xs text-gray-500">All knowledge base entries across categories & statuses. Newest first.</p>
        <DataTable
          rows={articles}
          columns={articleCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Top Viewed</h2>
        <p className="text-xs text-gray-500">Published articles ranked by view count — signal of what knowledge founders rely on most.</p>
        <DataTable
          rows={top}
          columns={topCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Stale — Needing Review</h2>
        <p className="text-xs text-gray-500">Published articles not reviewed in &gt;= 90 days. Re-review or archive.</p>
        <DataTable
          rows={stale}
          columns={staleCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Recent Views</h2>
        <p className="text-xs text-gray-500">Last 50 article opens — who is reading what, & what they searched for.</p>
        <DataTable
          rows={views}
          columns={viewCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
