import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [refsRes, usesRes, featuredRes, recentRes] = await Promise.all([
    sb.rpc('list_references_r2119'),
    sb.rpc('list_uses_r2119', { p_reference_id: null }),
    sb.rpc('featured_r2119'),
    sb.rpc('recent_uses_r2119', { p_days: 30 }),
  ]);

  const refs: any[] = refsRes.data ?? [];
  const uses: any[] = usesRes.data ?? [];
  const featured: any[] = featuredRes.data ?? [];
  const recent: any[] = recentRes.data ?? [];

  const refsCols: Column<any>[] = [
    { key: 'captured_at', header: 'Captured', render: (r: any) => new Date(r.captured_at).toLocaleString() },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? r.hospital_id?.slice(0, 8) },
    { key: 'quote_source', header: 'Source', render: (r: any) => r.quote_source },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'reference_quote_md', header: 'Quote', render: (r: any) => (r.reference_quote_md ?? '').slice(0, 140) },
  ];

  const featuredCols: Column<any>[] = [
    { key: 'captured_at', header: 'Captured', render: (r: any) => new Date(r.captured_at).toLocaleString() },
    { key: 'quote_source', header: 'Source', render: (r: any) => r.quote_source },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => r.hospital_id?.slice(0, 8) },
    { key: 'reference_quote_md', header: 'Quote', render: (r: any) => (r.reference_quote_md ?? '').slice(0, 200) },
  ];

  const usesCols: Column<any>[] = [
    { key: 'used_at', header: 'Used', render: (r: any) => new Date(r.used_at).toLocaleString() },
    { key: 'use_type', header: 'Channel', render: (r: any) => r.use_type },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
    { key: 'reference_id', header: 'Ref', render: (r: any) => r.reference_id?.slice(0, 8) },
    { key: 'notes_md', header: 'Notes', render: (r: any) => (r.notes_md ?? '').slice(0, 120) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'use_type', header: 'Channel', render: (r: any) => r.use_type },
    { key: 'use_count', header: 'Uses (30 days)', render: (r: any) => String(r.use_count) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 4 }}>Hospital Customer Reference Library</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Curated customer quotes for marketing, awards, pitch decks, and sales calls. Round r2119.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>Featured references</h2>
        <DataTable rows={featured} columns={featuredCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>Recent use mix (last 30 days)</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.use_type ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>All references</h2>
        <DataTable rows={refs} columns={refsCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 8 }}>Use log</h2>
        <DataTable rows={uses} columns={usesCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
