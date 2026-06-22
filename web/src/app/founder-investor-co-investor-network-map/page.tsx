import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [relsRes, strongRes, recentRes] = await Promise.all([
    sb.rpc('list_co_investor_relationships_r2033'),
    sb.rpc('strong_co_investor_relationships_r2033'),
    sb.rpc('recent_co_investor_actions_r2033', { p_days: 30 }),
  ]);

  const rels: any[] = Array.isArray(relsRes.data) ? relsRes.data : [];
  const strong: any[] = Array.isArray(strongRes.data) ? strongRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const relsCols: Column<any>[] = [
    { key: 'id', header: 'ID', render: (r: any) => String(r.id ?? '').slice(0, 8) },
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id ?? '').slice(0, 8) },
    { key: 'co_investor_id_referenced', header: 'Co-Investor', render: (r: any) => String(r.co_investor_id_referenced ?? '').slice(0, 8) },
    { key: 'relationship_strength', header: 'Strength', render: (r: any) => String(r.relationship_strength ?? '') },
    { key: 'shared_deals_count', header: 'Shared Deals', render: (r: any) => String(r.shared_deals_count ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const strongCols: Column<any>[] = [
    { key: 'id', header: 'ID', render: (r: any) => String(r.id ?? '').slice(0, 8) },
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id ?? '').slice(0, 8) },
    { key: 'co_investor_id_referenced', header: 'Co-Investor', render: (r: any) => String(r.co_investor_id_referenced ?? '').slice(0, 8) },
    { key: 'shared_deals_count', header: 'Shared Deals', render: (r: any) => String(r.shared_deals_count ?? 0) },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'id', header: 'ID', render: (r: any) => String(r.id ?? '').slice(0, 8) },
    { key: 'relationship_id', header: 'Relationship', render: (r: any) => String(r.relationship_id ?? '').slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Investor Co-Investor Network Map</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track relationships between investors and the co-investors they reference. Strong, active links
        flag warm intro paths; recent action log shows what is moving this month.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Relationships</h2>
        <DataTable
          rows={rels}
          columns={relsCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Strong Active Relationships</h2>
        <DataTable
          rows={strong}
          columns={strongCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Actions (last 30 days)</h2>
        <DataTable
          rows={recent}
          columns={recentCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
