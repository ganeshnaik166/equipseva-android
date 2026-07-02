import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderRoadmapPublicViewPage() {
  const sb = await getSupabaseServerClient();

  const [roadmapRes, topRes, summaryRes] = await Promise.all([
    sb.rpc('list_roadmap_r1750'),
    sb.rpc('top_voted_items_r1750', { p_limit: 10 }),
    sb.rpc('public_roadmap_summary_r1750'),
  ]);

  const roadmap = (roadmapRes.data ?? []) as any[];
  const top = (topRes.data ?? []) as any[];
  const summary = (summaryRes.data ?? []) as any[];

  const roadmapCols: Column<any>[] = [
    { key: 'item_title', header: 'Item', render: (r: any) => String(r.item_title ?? '') },
    { key: 'category', header: 'Category', render: (r: any) => String(r.category ?? '') },
    { key: 'target_quarter', header: 'Target Qtr', render: (r: any) => String(r.target_quarter ?? '-') },
    { key: 'vote_count', header: 'Votes', render: (r: any) => String(r.vote_count ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'created_at', header: 'Created', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleDateString() : '-' },
  ];

  const topCols: Column<any>[] = [
    { key: 'item_title', header: 'Item', render: (r: any) => String(r.item_title ?? '') },
    { key: 'category', header: 'Category', render: (r: any) => String(r.category ?? '') },
    { key: 'vote_count', header: 'Votes', render: (r: any) => String(r.vote_count ?? 0) },
    { key: 'target_quarter', header: 'Target Qtr', render: (r: any) => String(r.target_quarter ?? '-') },
  ];

  const summaryCols: Column<any>[] = [
    { key: 'category', header: 'Category', render: (r: any) => String(r.category ?? '') },
    { key: 'item_count', header: 'Items', render: (r: any) => String(r.item_count ?? 0) },
    { key: 'total_votes', header: 'Total Votes', render: (r: any) => String(r.total_votes ?? 0) },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Founder Roadmap Public View</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Public-facing product roadmap items investors & customers can see and vote on.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Category Summary</h2>
        <DataTable
          rows={summary}
          columns={summaryCols}
          rowKey={(r: any, i: number) => String(r.category ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top Voted Items</h2>
        <DataTable
          rows={top}
          columns={topCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Roadmap Items</h2>
        <DataTable
          rows={roadmap}
          columns={roadmapCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
