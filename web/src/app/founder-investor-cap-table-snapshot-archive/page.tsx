import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [snapsRes, reviewsRes, latestRes] = await Promise.all([
    sb.rpc('list_cap_snapshots_r2021'),
    sb.rpc('recent_cap_snapshot_reviews_r2021', { p_limit: 20 }),
    sb.rpc('latest_cap_snapshot_r2021'),
  ]);

  const snaps: any[] = Array.isArray(snapsRes.data) ? snapsRes.data : [];
  const reviews: any[] = Array.isArray(reviewsRes.data) ? reviewsRes.data : [];
  const latest: any[] = Array.isArray(latestRes.data) ? latestRes.data : [];

  const snapCols: Column<any>[] = [
    { key: 'snapshot_label', header: 'Label', render: (r: any) => String(r.snapshot_label ?? '') },
    { key: 'snapshot_date', header: 'Date', render: (r: any) => String(r.snapshot_date ?? '') },
    { key: 'total_shares', header: 'Total Shares', render: (r: any) => String(r.total_shares ?? 0) },
    { key: 'founder_shares', header: 'Founder', render: (r: any) => String(r.founder_shares ?? 0) },
    { key: 'investor_shares', header: 'Investor', render: (r: any) => String(r.investor_shares ?? 0) },
    { key: 'option_pool_shares', header: 'Option Pool', render: (r: any) => String(r.option_pool_shares ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const reviewCols: Column<any>[] = [
    { key: 'snapshot_id', header: 'Snapshot', render: (r: any) => String(r.snapshot_id ?? '').slice(0, 8) },
    { key: 'review_type', header: 'Type', render: (r: any) => String(r.review_type ?? '') },
    { key: 'by_email', header: 'Reviewer', render: (r: any) => String(r.by_email ?? '') },
    { key: 'reviewed_at', header: 'Reviewed', render: (r: any) => r.reviewed_at ? new Date(r.reviewed_at).toLocaleString() : '' },
    { key: 'finding_md', header: 'Finding', render: (r: any) => String(r.finding_md ?? '').slice(0, 80) },
  ];

  const latestCols: Column<any>[] = [
    { key: 'snapshot_label', header: 'Label', render: (r: any) => String(r.snapshot_label ?? '') },
    { key: 'snapshot_date', header: 'Date', render: (r: any) => String(r.snapshot_date ?? '') },
    { key: 'total_shares', header: 'Total', render: (r: any) => String(r.total_shares ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Investor Cap Table Snapshot Archive</h1>
        <p className="text-sm text-gray-600">Point-in-time cap table snapshots and review log.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Latest Active Snapshot</h2>
        <DataTable rows={latest} columns={latestCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Snapshots</h2>
        <DataTable rows={snaps} columns={snapCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Reviews</h2>
        <DataTable rows={reviews} columns={reviewCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
