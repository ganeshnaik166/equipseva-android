import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Article = { slug: string; title: string; author_engineer: string; topic: string; quarter: string; page_views: number; hn_points: number; hires_attributed: number; verdict: string };
type Signal = { topic: string; target_articles_per_quarter: number; articles_shipped: number; avg_engagement_score: number; recruit_signal: string; notes: string | null };
type Kpi = { total_articles: number; total_views: number; total_hires: number; viral_count: number; dud_count: number };
type Author = { author_engineer: string; articles: number; total_views: number; total_hires: number };
type Viral = { slug: string; title: string; page_views: number; hn_points: number; hires_attributed: number };
type Dud = { slug: string; title: string; topic: string; page_views: number; verdict: string };
type Quarter = { quarter: string; articles: number; views: number; hires: number; viral: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [articlesRes, signalsRes, kpisRes, authorsRes, viralRes, dudsRes, quarterRes] = await Promise.all([
    supabase.rpc('founder_blog_articles_list_r2881'),
    supabase.rpc('founder_blog_topic_signals_r2881'),
    supabase.rpc('founder_blog_kpis_r2881'),
    supabase.rpc('founder_blog_top_authors_r2881'),
    supabase.rpc('founder_blog_viral_only_r2881'),
    supabase.rpc('founder_blog_duds_r2881'),
    supabase.rpc('founder_blog_quarter_summary_r2881'),
  ]);

  const articles = (articlesRes.data ?? []) as Article[];
  const signals = (signalsRes.data ?? []) as Signal[];
  const kpis = ((kpisRes.data ?? [])[0] ?? { total_articles: 0, total_views: 0, total_hires: 0, viral_count: 0, dud_count: 0 }) as Kpi;
  const authors = (authorsRes.data ?? []) as Author[];
  const viral = (viralRes.data ?? []) as Viral[];
  const duds = (dudsRes.data ?? []) as Dud[];
  const quarters = (quarterRes.data ?? []) as Quarter[];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Quarterly Strategic Engineering Blog Publishing</h1>
        <p className="text-sm text-gray-600">Engineer × article × topic × signal × engagement × hire impact × verdict.</p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
        <div className="p-4 border rounded"><div className="text-xs text-gray-500">Total articles</div><div className="text-2xl font-bold">{kpis.total_articles}</div></div>
        <div className="p-4 border rounded"><div className="text-xs text-gray-500">Total views</div><div className="text-2xl font-bold">{kpis.total_views}</div></div>
        <div className="p-4 border rounded"><div className="text-xs text-gray-500">Hires attributed</div><div className="text-2xl font-bold">{kpis.total_hires}</div></div>
        <div className="p-4 border rounded"><div className="text-xs text-gray-500">Viral</div><div className="text-2xl font-bold">{kpis.viral_count}</div></div>
        <div className="p-4 border rounded"><div className="text-xs text-gray-500">Duds</div><div className="text-2xl font-bold">{kpis.dud_count}</div></div>
      </div>

      <section>
        <h2 className="text-xl font-semibold mb-2">Articles shipped</h2>
        <DataTable
          rows={articles}
          columns={[
            { key: 'title', header: 'Title', render: (r: Article) => r.title },
            { key: 'author_engineer', header: 'Engineer', render: (r: Article) => r.author_engineer },
            { key: 'topic', header: 'Topic', render: (r: Article) => r.topic },
            { key: 'quarter', header: 'Quarter', render: (r: Article) => r.quarter },
            { key: 'page_views', header: 'Views', render: (r: Article) => r.page_views.toLocaleString() },
            { key: 'hn_points', header: 'HN', render: (r: Article) => r.hn_points },
            { key: 'hires_attributed', header: 'Hires', render: (r: Article) => r.hires_attributed },
            { key: 'verdict', header: 'Verdict', render: (r: Article) => r.verdict },
          ]}
          emptyMessage="No data"
          rowKey={(r: Article, i: number) => String(r.slug ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-2">Topic signals</h2>
        <DataTable
          rows={signals}
          columns={[
            { key: 'topic', header: 'Topic', render: (r: Signal) => r.topic },
            { key: 'target_articles_per_quarter', header: 'Target / Q', render: (r: Signal) => r.target_articles_per_quarter },
            { key: 'articles_shipped', header: 'Shipped', render: (r: Signal) => r.articles_shipped },
            { key: 'avg_engagement_score', header: 'Engagement', render: (r: Signal) => r.avg_engagement_score },
            { key: 'recruit_signal', header: 'Recruit signal', render: (r: Signal) => r.recruit_signal },
            { key: 'notes', header: 'Notes', render: (r: Signal) => r.notes ?? '' },
          ]}
          emptyMessage="No data"
          rowKey={(r: Signal, i: number) => String(r.topic ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-2">Top authors</h2>
        <DataTable
          rows={authors}
          columns={[
            { key: 'author_engineer', header: 'Engineer', render: (r: Author) => r.author_engineer },
            { key: 'articles', header: 'Articles', render: (r: Author) => r.articles },
            { key: 'total_views', header: 'Views', render: (r: Author) => Number(r.total_views).toLocaleString() },
            { key: 'total_hires', header: 'Hires', render: (r: Author) => r.total_hires },
          ]}
          emptyMessage="No data"
          rowKey={(r: Author, i: number) => String(r.author_engineer ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-2">Viral picks</h2>
        <DataTable
          rows={viral}
          columns={[
            { key: 'title', header: 'Title', render: (r: Viral) => r.title },
            { key: 'page_views', header: 'Views', render: (r: Viral) => r.page_views.toLocaleString() },
            { key: 'hn_points', header: 'HN', render: (r: Viral) => r.hn_points },
            { key: 'hires_attributed', header: 'Hires', render: (r: Viral) => r.hires_attributed },
          ]}
          emptyMessage="No data"
          rowKey={(r: Viral, i: number) => String(r.slug ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-2">Duds</h2>
        <DataTable
          rows={duds}
          columns={[
            { key: 'title', header: 'Title', render: (r: Dud) => r.title },
            { key: 'topic', header: 'Topic', render: (r: Dud) => r.topic },
            { key: 'page_views', header: 'Views', render: (r: Dud) => r.page_views.toLocaleString() },
            { key: 'verdict', header: 'Verdict', render: (r: Dud) => r.verdict },
          ]}
          emptyMessage="No data"
          rowKey={(r: Dud, i: number) => String(r.slug ?? i)}
        />
      </section>

      <section>
        <h2 className="text-xl font-semibold mb-2">Quarter summary</h2>
        <DataTable
          rows={quarters}
          columns={[
            { key: 'quarter', header: 'Quarter', render: (r: Quarter) => r.quarter },
            { key: 'articles', header: 'Articles', render: (r: Quarter) => r.articles },
            { key: 'views', header: 'Views', render: (r: Quarter) => Number(r.views).toLocaleString() },
            { key: 'hires', header: 'Hires', render: (r: Quarter) => r.hires },
            { key: 'viral', header: 'Viral', render: (r: Quarter) => r.viral },
          ]}
          emptyMessage="No data"
          rowKey={(r: Quarter, i: number) => String(r.quarter ?? i)}
        />
      </section>
    </div>
  );
}
