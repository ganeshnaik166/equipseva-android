import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderCustomerWishlistAggregatorPage() {
  const sb = await getSupabaseServerClient();

  const [wishlistRes, topVotedRes, summaryRes] = await Promise.all([
    sb.rpc('list_wishlist_r1730'),
    sb.rpc('top_voted_requests_r1730'),
    sb.rpc('recent_capture_summary_r1730'),
  ]);

  const wishlist: any[] = Array.isArray(wishlistRes.data) ? wishlistRes.data : [];
  const topVoted: any[] = Array.isArray(topVotedRes.data) ? topVotedRes.data : [];
  const summary: any = Array.isArray(summaryRes.data) ? summaryRes.data[0] ?? {} : summaryRes.data ?? {};

  const wishlistCols: Column<any>[] = [
    { key: 'request_title', header: 'Request', render: (r: any) => String(r.request_title ?? '') },
    { key: 'source', header: 'Source', render: (r: any) => String(r.source ?? '') },
    { key: 'importance', header: 'Importance', render: (r: any) => String(r.importance ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'votes_count', header: 'Votes', render: (r: any) => String(r.votes_count ?? 0) },
    { key: 'captured_by_email', header: 'Captured By', render: (r: any) => String(r.captured_by_email ?? '') },
    { key: 'created_at', header: 'Captured At', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleString() : '' },
  ];

  const topVotedCols: Column<any>[] = [
    { key: 'request_title', header: 'Request', render: (r: any) => String(r.request_title ?? '') },
    { key: 'votes_count', header: 'Votes', render: (r: any) => String(r.votes_count ?? 0) },
    { key: 'importance', header: 'Importance', render: (r: any) => String(r.importance ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'source', header: 'Source', render: (r: any) => String(r.source ?? '') },
  ];

  const summaryRows = [
    { label: 'Total Requests', value: String(summary.total_requests ?? 0) },
    { label: 'Critical Importance', value: String(summary.critical_count ?? 0) },
    { label: 'In Roadmap', value: String(summary.in_roadmap_count ?? 0) },
    { label: 'Built', value: String(summary.built_count ?? 0) },
    { label: 'Declined', value: String(summary.declined_count ?? 0) },
    { label: 'Captured Last 7 Days', value: String(summary.last_7d_count ?? 0) },
    { label: 'Total Votes', value: String(summary.total_votes ?? 0) },
  ];

  const summaryCols: Column<any>[] = [
    { key: 'label', header: 'Metric', render: (r: any) => String(r.label ?? '') },
    { key: 'value', header: 'Value', render: (r: any) => String(r.value ?? '') },
  ];

  return (
    <main className="p-6 max-w-7xl mx-auto">
      <h1 className="text-2xl font-bold mb-2">Founder Customer Wishlist Aggregator</h1>
      <p className="text-sm text-gray-600 mb-6">
        Aggregated feature requests and pain points from customers across calls, emails, visits, surveys and support tickets.
        Critical items (votes &gt;= roadmap threshold) flow into roadmap planning.
      </p>

      <section className="mb-8">
        <h2 className="text-lg font-semibold mb-3">Capture Summary</h2>
        <DataTable rows={summaryRows} columns={summaryCols} rowKey={(r: any, i: number) => String(r.label ?? i)} />
      </section>

      <section className="mb-8">
        <h2 className="text-lg font-semibold mb-3">Top Voted Requests (votes &gt;= 1)</h2>
        <DataTable rows={topVoted} columns={topVotedCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="mb-8">
        <h2 className="text-lg font-semibold mb-3">All Wishlist Items (latest 200)</h2>
        <DataTable rows={wishlist} columns={wishlistCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
