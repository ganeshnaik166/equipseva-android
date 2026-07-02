import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderInspirationLibraryPage() {
  const sb = await getSupabaseServerClient();

  const [inspirationsRes, applicationsRes, topRatedRes, takeawaysRes, summaryRes] = await Promise.all([
    sb.rpc('list_inspirations_r1726'),
    sb.rpc('list_applications_r1726'),
    sb.rpc('top_rated_r1726'),
    sb.rpc('recent_takeaways_r1726'),
    sb.rpc('applied_inspirations_summary_r1726'),
  ]);

  const inspirations: any[] = Array.isArray(inspirationsRes.data) ? inspirationsRes.data : [];
  const applications: any[] = Array.isArray(applicationsRes.data) ? applicationsRes.data : [];
  const topRated: any[] = Array.isArray(topRatedRes.data) ? topRatedRes.data : [];
  const takeaways: any[] = Array.isArray(takeawaysRes.data) ? takeawaysRes.data : [];
  const summary: any[] = Array.isArray(summaryRes.data) ? summaryRes.data : [];

  const fmtDate = (s: any) => (s ? new Date(String(s)).toLocaleDateString() : '—');
  const fmtDateTime = (s: any) => (s ? new Date(String(s)).toLocaleString() : '—');
  const trunc = (s: any, n = 120) => {
    const v = s == null ? '' : String(s);
    return v.length > n ? v.slice(0, n) + '…' : v;
  };

  const inspirationCols: Column<any>[] = [
    { key: 'consumed_at', header: 'Consumed', render: (r: any) => fmtDate(r.consumed_at) },
    { key: 'source_type', header: 'Type', render: (r: any) => String(r.source_type ?? '—') },
    { key: 'title', header: 'Title', render: (r: any) => String(r.title ?? '—') },
    { key: 'author', header: 'Author', render: (r: any) => String(r.author ?? '—') },
    { key: 'rating', header: 'Rating', render: (r: any) => (r.rating == null ? '—' : `${r.rating}/10`) },
    { key: 'would_recommend', header: 'Recommend', render: (r: any) => (r.would_recommend ? 'Yes' : 'No') },
    { key: 'app_count', header: 'Applications', render: (r: any) => String(r.app_count ?? 0) },
  ];

  const applicationCols: Column<any>[] = [
    { key: 'applied_at', header: 'Applied', render: (r: any) => fmtDateTime(r.applied_at) },
    { key: 'inspiration_title', header: 'From', render: (r: any) => String(r.inspiration_title ?? '—') },
    { key: 'applied_to', header: 'Applied To', render: (r: any) => String(r.applied_to ?? '—') },
    { key: 'application_note', header: 'Note', render: (r: any) => trunc(r.application_note, 100) },
    { key: 'has_outcome', header: 'Outcome Logged', render: (r: any) => (r.has_outcome ? 'Yes' : 'No') },
  ];

  const topRatedCols: Column<any>[] = [
    { key: 'rating', header: 'Rating', render: (r: any) => (r.rating == null ? '—' : `${r.rating}/10`) },
    { key: 'source_type', header: 'Type', render: (r: any) => String(r.source_type ?? '—') },
    { key: 'title', header: 'Title', render: (r: any) => String(r.title ?? '—') },
    { key: 'author', header: 'Author', render: (r: any) => String(r.author ?? '—') },
    { key: 'would_recommend', header: 'Recommend', render: (r: any) => (r.would_recommend ? 'Yes' : 'No') },
    { key: 'consumed_at', header: 'Consumed', render: (r: any) => fmtDate(r.consumed_at) },
  ];

  const takeawayCols: Column<any>[] = [
    { key: 'consumed_at', header: 'Consumed', render: (r: any) => fmtDate(r.consumed_at) },
    { key: 'source_type', header: 'Type', render: (r: any) => String(r.source_type ?? '—') },
    { key: 'title', header: 'Title', render: (r: any) => String(r.title ?? '—') },
    { key: 'rating', header: 'Rating', render: (r: any) => (r.rating == null ? '—' : `${r.rating}/10`) },
    { key: 'key_takeaways_md', header: 'Takeaways', render: (r: any) => trunc(r.key_takeaways_md, 180) },
  ];

  const summaryCols: Column<any>[] = [
    { key: 'source_type', header: 'Type', render: (r: any) => String(r.source_type ?? '—') },
    { key: 'total_inspirations', header: 'Total', render: (r: any) => String(r.total_inspirations ?? 0) },
    { key: 'applied_count', header: 'Applied', render: (r: any) => String(r.applied_count ?? 0) },
    { key: 'recommend_count', header: 'Recommended', render: (r: any) => String(r.recommend_count ?? 0) },
    { key: 'avg_rating', header: 'Avg Rating', render: (r: any) => (r.avg_rating == null ? '—' : String(r.avg_rating)) },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '8px' }}>Founder Inspiration Library</h1>
      <p style={{ color: '#666', marginBottom: '32px' }}>
        Books, articles, podcasts, talks, and conversations consumed — with key takeaways and how they
        applied to the business. Rating scale 1–10, top picks are rating &gt;= 8.
      </p>

      <section style={{ marginBottom: '40px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Summary by Source Type</h2>
        <p style={{ color: '#666', marginBottom: '12px', fontSize: '14px' }}>
          Aggregate counts per source type — total consumed, how many were applied, and average rating.
        </p>
        <DataTable
          rows={summary}
          columns={summaryCols}
          rowKey={(r: any, i: number) => String(r.source_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '40px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Top Rated (rating &gt;= 8)</h2>
        <p style={{ color: '#666', marginBottom: '12px', fontSize: '14px' }}>
          Highest-rated inspirations — the ones worth revisiting.
        </p>
        <DataTable
          rows={topRated}
          columns={topRatedCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '40px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Recent Takeaways</h2>
        <p style={{ color: '#666', marginBottom: '12px', fontSize: '14px' }}>
          Latest 25 inspirations with logged key takeaways.
        </p>
        <DataTable
          rows={takeaways}
          columns={takeawayCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '40px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>All Inspirations</h2>
        <p style={{ color: '#666', marginBottom: '12px', fontSize: '14px' }}>
          Complete library — books, articles, podcasts, talks, movies, conversations.
        </p>
        <DataTable
          rows={inspirations}
          columns={inspirationCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '40px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Applications Log</h2>
        <p style={{ color: '#666', marginBottom: '12px', fontSize: '14px' }}>
          Where ideas from the library got applied to EquipSeva — product, ops, hiring, fundraise, etc.
        </p>
        <DataTable
          rows={applications}
          columns={applicationCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
