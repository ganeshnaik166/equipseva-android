import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [logsRes, sourcesRes, topRes, trendRes, appliedRes] = await Promise.all([
    sb.rpc('list_logs_r1830', { p_limit: 26 }),
    sb.rpc('list_sources_r1830', { p_week_start: null, p_limit: 100 }),
    sb.rpc('top_helpful_sources_r1830', { p_limit: 20 }),
    sb.rpc('monthly_reading_trend_r1830', { p_months: 12 }),
    sb.rpc('applied_summary_r1830', { p_limit: 20 }),
  ]);

  const logs: any[] = logsRes.data ?? [];
  const sources: any[] = sourcesRes.data ?? [];
  const top: any[] = topRes.data ?? [];
  const trend: any[] = trendRes.data ?? [];
  const applied: any[] = appliedRes.data ?? [];

  const logCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => String(r.week_start ?? '') },
    { key: 'articles_read', header: 'Articles', render: (r: any) => String(r.articles_read ?? 0) },
    { key: 'books_pages_read', header: 'Book Pages', render: (r: any) => String(r.books_pages_read ?? 0) },
    { key: 'podcasts_minutes', header: 'Podcast Min', render: (r: any) => String(r.podcasts_minutes ?? 0) },
    { key: 'talks_watched', header: 'Talks', render: (r: any) => String(r.talks_watched ?? 0) },
    { key: 'key_takeaways_md', header: 'Takeaways', render: (r: any) => (r.key_takeaways_md ? String(r.key_takeaways_md).slice(0, 80) : '-') },
    { key: 'applied_to_business_md', header: 'Applied', render: (r: any) => (r.applied_to_business_md ? String(r.applied_to_business_md).slice(0, 80) : '-') },
  ];

  const sourceCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => String(r.week_start ?? '') },
    { key: 'source_type', header: 'Type', render: (r: any) => String(r.source_type ?? '') },
    { key: 'source_label', header: 'Label', render: (r: any) => String(r.source_label ?? '') },
    { key: 'duration_minutes', header: 'Min', render: (r: any) => String(r.duration_minutes ?? 0) },
    { key: 'helpful_score', header: 'Helpful', render: (r: any) => String(r.helpful_score ?? 0) + ' / 10' },
  ];

  const topCols: Column<any>[] = [
    { key: 'source_type', header: 'Type', render: (r: any) => String(r.source_type ?? '') },
    { key: 'source_label', header: 'Label', render: (r: any) => String(r.source_label ?? '') },
    { key: 'week_start', header: 'Week', render: (r: any) => String(r.week_start ?? '') },
    { key: 'helpful_score', header: 'Score', render: (r: any) => String(r.helpful_score ?? 0) },
    { key: 'duration_minutes', header: 'Min', render: (r: any) => String(r.duration_minutes ?? 0) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => String(r.month_start ?? '') },
    { key: 'weeks_logged', header: 'Weeks', render: (r: any) => String(r.weeks_logged ?? 0) },
    { key: 'total_articles', header: 'Articles', render: (r: any) => String(r.total_articles ?? 0) },
    { key: 'total_book_pages', header: 'Pages', render: (r: any) => String(r.total_book_pages ?? 0) },
    { key: 'total_podcast_minutes', header: 'Pod Min', render: (r: any) => String(r.total_podcast_minutes ?? 0) },
    { key: 'total_talks', header: 'Talks', render: (r: any) => String(r.total_talks ?? 0) },
    { key: 'avg_helpful_score', header: 'Avg Helpful', render: (r: any) => String(r.avg_helpful_score ?? 0) },
  ];

  const appliedCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => String(r.week_start ?? '') },
    { key: 'applied_to_business_md', header: 'Applied To Business', render: (r: any) => (r.applied_to_business_md ? String(r.applied_to_business_md).slice(0, 120) : '-') },
    { key: 'key_takeaways_md', header: 'Takeaways', render: (r: any) => (r.key_takeaways_md ? String(r.key_takeaways_md).slice(0, 80) : '-') },
    { key: 'total_minutes', header: 'Total Min', render: (r: any) => String(r.total_minutes ?? 0) },
    { key: 'source_count', header: 'Sources', render: (r: any) => String(r.source_count ?? 0) },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1280, margin: '0 auto', fontFamily: 'system-ui, -apple-system, sans-serif' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 4 }}>Founder Weekly Reading Log</h1>
      <p style={{ color: '#666', marginBottom: 24, fontSize: 14 }}>
        Weekly intake of articles, books, podcasts & talks — with takeaways & how they applied to the business.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Weekly log ({logs.length})</h2>
        <DataTable rows={logs} columns={logCols} rowKey={(r: any, i: number) => String(r.week_start ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Monthly trend</h2>
        <DataTable rows={trend} columns={trendCols} rowKey={(r: any, i: number) => String(r.month_start ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top helpful sources (score &gt;= 8 typical)</h2>
        <DataTable rows={top} columns={topCols} rowKey={(r: any, i: number) => String(i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Source breakdown ({sources.length})</h2>
        <DataTable rows={sources} columns={sourceCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Applied-to-business notes</h2>
        <DataTable rows={applied} columns={appliedCols} rowKey={(r: any, i: number) => String(r.week_start ?? i)} />
      </section>
    </div>
  );
}
