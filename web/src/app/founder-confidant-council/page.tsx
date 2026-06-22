import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderConfidantCouncilPage() {
  const sb = await getSupabaseServerClient();

  const [confidantsRes, topTopicsRes, recentRes] = await Promise.all([
    sb.rpc('list_confidants_r1966'),
    sb.rpc('top_topics_r1966'),
    sb.rpc('recent_consultations_r1966'),
  ]);

  const confidants: any[] = Array.isArray(confidantsRes.data) ? confidantsRes.data : [];
  const topics: any[] = Array.isArray(topTopicsRes.data) ? topTopicsRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const confidantCols: Column<any>[] = [
    { key: 'confidant_name', header: 'Name', render: (r: any) => String(r.confidant_name ?? '') },
    { key: 'confidant_role', header: 'Role', render: (r: any) => String(r.confidant_role ?? '').replace(/_/g, ' ') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'consultation_count', header: 'Consultations', render: (r: any) => String(r.consultation_count ?? 0) },
    {
      key: 'last_consultation_at',
      header: 'Last Consulted',
      render: (r: any) => (r.last_consultation_at ? new Date(r.last_consultation_at).toLocaleDateString() : 'never'),
    },
  ];

  const topicCols: Column<any>[] = [
    { key: 'topic_category', header: 'Topic', render: (r: any) => String(r.topic_category ?? '').replace(/_/g, ' ') },
    { key: 'consultation_count', header: 'Count', render: (r: any) => String(r.consultation_count ?? 0) },
    {
      key: 'last_at',
      header: 'Last',
      render: (r: any) => (r.last_at ? new Date(r.last_at).toLocaleDateString() : '—'),
    },
  ];

  const recentCols: Column<any>[] = [
    {
      key: 'consultation_at',
      header: 'When',
      render: (r: any) => (r.consultation_at ? new Date(r.consultation_at).toLocaleDateString() : '—'),
    },
    { key: 'confidant_name', header: 'Confidant', render: (r: any) => String(r.confidant_name ?? '') },
    { key: 'confidant_role', header: 'Role', render: (r: any) => String(r.confidant_role ?? '').replace(/_/g, ' ') },
    { key: 'topic_category', header: 'Topic', render: (r: any) => String(r.topic_category ?? '').replace(/_/g, ' ') },
    {
      key: 'outcome_md',
      header: 'Outcome',
      render: (r: any) => {
        const s = String(r.outcome_md ?? '');
        return s.length > 120 ? s.slice(0, 120) + '…' : s;
      },
    },
  ];

  const activeCount = confidants.filter((c) => c.status === 'active').length;
  const lostCount = confidants.filter((c) => c.status === 'lost').length;

  return (
    <div className="mx-auto max-w-7xl p-6 space-y-8">
      <header className="space-y-2">
        <h1 className="text-2xl font-bold">Founder Confidant Council</h1>
        <p className="text-sm text-gray-600">
          Private advisors, mentors, and trusted relationships. {activeCount} active confidants and {lostCount} lost over time.
        </p>
      </header>

      <section className="space-y-3">
        <div>
          <h2 className="text-lg font-semibold">Confidants</h2>
          <p className="text-sm text-gray-600">All tracked advisors, ordered by active status and recency of last consultation.</p>
        </div>
        <DataTable rows={confidants} columns={confidantCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-3">
        <div>
          <h2 className="text-lg font-semibold">Top Topics</h2>
          <p className="text-sm text-gray-600">Topic categories ranked by total consultation count across all confidants.</p>
        </div>
        <DataTable rows={topics} columns={topicCols} rowKey={(r: any, i: number) => String(r.topic_category ?? i)} />
      </section>

      <section className="space-y-3">
        <div>
          <h2 className="text-lg font-semibold">Recent Consultations</h2>
          <p className="text-sm text-gray-600">Consultations within the last 60 days, up to 50 entries.</p>
        </div>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
