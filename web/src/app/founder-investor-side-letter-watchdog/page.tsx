import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [lettersRes, activeRes, recentRes] = await Promise.all([
    sb.rpc('list_letters_r1993'),
    sb.rpc('active_letters_r1993'),
    sb.rpc('recent_reviews_r1993', { p_days: 30 }),
  ]);

  const letters: any[] = Array.isArray(lettersRes.data) ? lettersRes.data : [];
  const active: any[] = Array.isArray(activeRes.data) ? activeRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const letterCols: Column<any>[] = [
    { key: 'label', header: 'Letter', render: (r: any) => String(r.letter_label ?? '') },
    { key: 'investor', header: 'Investor', render: (r: any) => String(r.investor_id ?? '').slice(0, 8) },
    { key: 'signed', header: 'Signed', render: (r: any) => r.signed_at ? new Date(r.signed_at).toLocaleDateString() : '' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'reviewed', header: 'Last reviewed', render: (r: any) => r.last_reviewed_at ? new Date(r.last_reviewed_at).toLocaleDateString() : 'never' },
  ];

  const activeCols: Column<any>[] = [
    { key: 'label', header: 'Letter', render: (r: any) => String(r.letter_label ?? '') },
    { key: 'investor', header: 'Investor', render: (r: any) => String(r.investor_id ?? '').slice(0, 8) },
    { key: 'signed', header: 'Signed', render: (r: any) => r.signed_at ? new Date(r.signed_at).toLocaleDateString() : '' },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'reviewed', header: 'Last reviewed', render: (r: any) => r.last_reviewed_at ? new Date(r.last_reviewed_at).toLocaleDateString() : 'never' },
  ];

  const reviewCols: Column<any>[] = [
    { key: 'type', header: 'Review type', render: (r: any) => String(r.review_type ?? '') },
    { key: 'when', header: 'Reviewed', render: (r: any) => r.reviewed_at ? new Date(r.reviewed_at).toLocaleString() : '' },
    { key: 'by', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'finding', header: 'Finding', render: (r: any) => String(r.finding_md ?? '').slice(0, 120) },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Investor side letter watchdog</h1>
        <p className="text-sm text-gray-600">Track active side letters and recent reviews to ensure terms remain honored.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Active letters (need oversight)</h2>
        <DataTable rows={active} columns={activeCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All side letters</h2>
        <DataTable rows={letters} columns={letterCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent reviews (past 30 days)</h2>
        <DataTable rows={recent} columns={reviewCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
