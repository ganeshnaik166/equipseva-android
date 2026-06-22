import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderWinsLedgerPage() {
  const sb = await getSupabaseServerClient();

  const [winsRes, catsRes, celebsRes] = await Promise.all([
    sb.rpc('list_wins_r1938', { p_limit: 100 }),
    sb.rpc('top_categories_r1938'),
    sb.rpc('recent_celebrations_r1938', { p_days: 30 }),
  ]);

  const wins: any[] = (winsRes.data as any[]) ?? [];
  const cats: any[] = (catsRes.data as any[]) ?? [];
  const celebs: any[] = (celebsRes.data as any[]) ?? [];

  const winsColumns: Column<any>[] = [
    { key: 'win_at', header: 'When', render: (r: any) => r.win_at ? new Date(r.win_at).toLocaleString() : '-' },
    { key: 'win_label', header: 'Win', render: (r: any) => String(r.win_label ?? '-') },
    { key: 'win_category', header: 'Category', render: (r: any) => String(r.win_category ?? '-') },
    { key: 'impact', header: 'Impact', render: (r: any) => String(r.impact ?? '-') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '-') },
    { key: 'celebration_count', header: 'Celebrations', render: (r: any) => String(r.celebration_count ?? 0) },
    { key: 'summary_md', header: 'Summary', render: (r: any) => String(r.summary_md ?? '-') },
  ];

  const catsColumns: Column<any>[] = [
    { key: 'win_category', header: 'Category', render: (r: any) => String(r.win_category ?? '-') },
    { key: 'win_count', header: 'Total Wins', render: (r: any) => String(r.win_count ?? 0) },
    { key: 'transformational_count', header: 'Transformational', render: (r: any) => String(r.transformational_count ?? 0) },
    { key: 'large_count', header: 'Large', render: (r: any) => String(r.large_count ?? 0) },
  ];

  const celebsColumns: Column<any>[] = [
    { key: 'celebration_type', header: 'Type', render: (r: any) => String(r.celebration_type ?? '-') },
    { key: 'celebration_count', header: 'Count', render: (r: any) => String(r.celebration_count ?? 0) },
    { key: 'unique_wins', header: 'Unique Wins', render: (r: any) => String(r.unique_wins ?? 0) },
    { key: 'latest_at', header: 'Latest', render: (r: any) => r.latest_at ? new Date(r.latest_at).toLocaleString() : '-' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', fontWeight: 700, marginBottom: '0.5rem' }}>
        Founder Wins Ledger
      </h1>
      <p style={{ color: '#666', marginBottom: '2rem' }}>
        160-batch ledger of what we shipped that mattered & how we celebrated it.
      </p>

      <section style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>
          Top categories
        </h2>
        <DataTable rows={cats} columns={catsColumns} rowKey={(r: any, i: number) => String(r.win_category ?? i)} />
      </section>

      <section style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>
          Recent celebrations (last 30 days)
        </h2>
        <DataTable rows={celebs} columns={celebsColumns} rowKey={(r: any, i: number) => String(r.celebration_type ?? i)} />
      </section>

      <section style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>
          All wins
        </h2>
        <DataTable rows={wins} columns={winsColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
