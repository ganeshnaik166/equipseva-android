import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [summary, topRead, lowRes, catMix, srcMix, feedback, stale] = await Promise.all([
    sb.rpc('r2252_summary'),
    sb.rpc('r2252_top_read_articles'),
    sb.rpc('r2252_low_resolution_articles'),
    sb.rpc('r2252_category_mix'),
    sb.rpc('r2252_read_source_mix'),
    sb.rpc('r2252_recent_feedback'),
    sb.rpc('r2252_stale_articles'),
  ]);

  const s = (summary.data ?? [])[0] ?? {};

  const topCols: Column<any>[] = [
    { key: 'article_code', header: 'Code', render: (r) => r.article_code },
    { key: 'title', header: 'Title', render: (r) => r.title },
    { key: 'category', header: 'Category', render: (r) => r.category },
    { key: 'audience', header: 'Audience', render: (r) => r.audience },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'total_reads', header: 'Reads 30d', render: (r) => r.total_reads },
    { key: 'unique_readers', header: 'Unique readers', render: (r) => r.unique_readers },
    { key: 'avg_seconds_on_page', header: 'Avg sec', render: (r) => r.avg_seconds_on_page ?? '—' },
  ];

  const lowCols: Column<any>[] = [
    { key: 'article_code', header: 'Code', render: (r) => r.article_code },
    { key: 'title', header: 'Title', render: (r) => r.title },
    { key: 'category', header: 'Category', render: (r) => r.category },
    { key: 'total_reads', header: 'Rated reads', render: (r) => r.total_reads },
    { key: 'resolved_count', header: 'Resolved', render: (r) => r.resolved_count },
    { key: 'resolution_rate_pct', header: 'Resolve %', render: (r) => r.resolution_rate_pct ?? '—' },
    { key: 'flagged', header: 'Flagged', render: (r) => (r.flagged ? 'yes' : '—') },
  ];

  const catCols: Column<any>[] = [
    { key: 'category', header: 'Category', render: (r) => r.category },
    { key: 'articles_published', header: 'Published', render: (r) => r.articles_published },
    { key: 'reads_30d', header: 'Reads 30d', render: (r) => r.reads_30d },
    { key: 'resolved_30d', header: 'Resolved 30d', render: (r) => r.resolved_30d },
    { key: 'resolution_rate_pct', header: 'Resolve %', render: (r) => r.resolution_rate_pct ?? '—' },
  ];

  const srcCols: Column<any>[] = [
    { key: 'read_source', header: 'Source', render: (r) => r.read_source },
    { key: 'reads_30d', header: 'Reads 30d', render: (r) => r.reads_30d },
    { key: 'helpful_pct', header: 'Helpful %', render: (r) => r.helpful_pct ?? '—' },
    { key: 'resolved_pct', header: 'Resolved %', render: (r) => r.resolved_pct ?? '—' },
  ];

  const fbCols: Column<any>[] = [
    { key: 'read_at', header: 'When', render: (r) => new Date(r.read_at).toLocaleString() },
    { key: 'article_code', header: 'Code', render: (r) => r.article_code },
    { key: 'title', header: 'Title', render: (r) => r.title },
    { key: 'reader_role', header: 'Role', render: (r) => r.reader_role },
    { key: 'rated_helpful', header: 'Helpful', render: (r) => (r.rated_helpful == null ? '—' : r.rated_helpful ? 'yes' : 'no') },
    { key: 'resolved_issue', header: 'Resolved', render: (r) => (r.resolved_issue == null ? '—' : r.resolved_issue ? 'yes' : 'no') },
    { key: 'feedback_note', header: 'Note', render: (r) => r.feedback_note },
  ];

  const staleCols: Column<any>[] = [
    { key: 'article_code', header: 'Code', render: (r) => r.article_code },
    { key: 'title', header: 'Title', render: (r) => r.title },
    { key: 'category', header: 'Category', render: (r) => r.category },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'days_since_update', header: 'Days stale', render: (r) => r.days_since_update },
    { key: 'reads_30d', header: 'Reads 30d', render: (r) => r.reads_30d },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
        Knowledge-Base Usage Analytics
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Which KB articles get read, which resolve issues, and which need a rewrite.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        <Stat label="Published" value={s.total_published ?? 0} />
        <Stat label="Flagged rewrite" value={s.flagged_for_rewrite ?? 0} />
        <Stat label="Reads 30d" value={s.reads_30d ?? 0} />
        <Stat label="Resolution rate" value={s.resolution_rate_pct == null ? '—' : `${s.resolution_rate_pct}%`} />
        <Stat label="Helpful rate" value={s.helpful_rate_pct == null ? '—' : `${s.helpful_rate_pct}%`} />
        <Stat label="Stale 180d+" value={s.stale_180d ?? 0} />
      </div>

      <Section title="Top read articles (30d)">
        <DataTable columns={topCols} rows={topRead.data ?? []} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Low resolution rate — needs rewrite (60d, min 5 rated reads)">
        <DataTable columns={lowCols} rows={lowRes.data ?? []} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Category mix">
        <DataTable columns={catCols} rows={catMix.data ?? []} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Read source mix">
        <DataTable columns={srcCols} rows={srcMix.data ?? []} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Recent reader feedback">
        <DataTable columns={fbCols} rows={feedback.data ?? []} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Stale published articles (not updated in 180d+)">
        <DataTable columns={staleCols} rows={stale.data ?? []} rowKey={(_, i) => String(i)} />
      </Section>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string | number }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
      <div style={{ fontSize: 12, color: '#6b7280', marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 600 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 32 }}>
      <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>{title}</h2>
      {children}
    </section>
  );
}
